#!/usr/bin/env python3
"""H1-B2: strictly read-only, provenance-bound candidate log normalizer.

No device contact, subprocess, network or file writes. Candidate matches are NOT
semantic Android events. Log clocks remain source-local, timezone UNKNOWN.
"""
import argparse
import hashlib
import json
import re
import stat
from collections import Counter
from pathlib import Path

SOURCES = {
    'OCT03_N1H': ('', '71d91f12aa455e26a1d474be157fad1989a1fce7a6cc6018dabc79a4fa9a10c4', 6936),
    'OCT07_STOCK': ('', '3e23000d91cd216a07cee55d90eab1d411c82baf26901547a4f3ed50bbdda76c', 6902),
    'OCT09_N1F_FAILURE': ('', '616790ba7ebc852247695807d1f2bbed344f16f24ab9c7c8cf9a4f56f33a3b98', 7587),
    'OCT09_POST_CYCLE': ('', 'd42278008725bbb85cc352b421a604fffb80f1aab7539e82bbc399dfb5ca5ef5', 9069),
}
STAMP = re.compile(rb'^\s*(?P<mm>\d{2})-(?P<dd>\d{2}) (?P<clock>\d{2}:\d{2}:\d{2}\.\d{3,6})\b')
# Pattern search identifies review candidates only, never sufficient for verdicts.
PATTERNS = {
    'VALIDATION_CANDIDATE': re.compile(rb'onInternetValidationStatusChanged|VALIDATED|validation', re.I),
    'DNS_CANDIDATE': re.compile(rb'\bDNS\b|DnsResolver|dns_probe', re.I),
    'VENDOR_DEACT_CANDIDATE': re.compile(rb'DATA_DEACT_CALL_IND|onDataCallDeact', re.I),
    'VENDOR_CAUSE_CANDIDATE': re.compile(rb'NETWORK CAUSE', re.I),
    'REGISTRATION_CANDIDATE': re.compile(rb'REGISTRATION|registration|reject.cause', re.I),
    'DATA_CALL_CANDIDATE': re.compile(rb'DATA_CALL|DataCall|ccmni', re.I),
    'DSRM_CANDIDATE': re.compile(rb'DSRM|DataStallRecovery', re.I),
}

class IntegrityError(Exception):
    pass

def read_source(label: str, path: Path, expected_sha: str, expected_lines: int):
    if path.is_symlink() or not path.is_file() or not stat.S_ISREG(path.stat().st_mode):
        raise IntegrityError(f'{label}: absent/symlink/nonregular source')
    h = hashlib.sha256()
    parsed = []
    counts = Counter()
    previous = None
    with path.open('rb') as stream:
        for lineno, line in enumerate(stream, 1):
            h.update(line)
            m = STAMP.match(line)
            counts['total_lines'] += 1
            if not m:
                counts['unparsed_timestamp_lines'] += 1
            else:
                mm, dd = int(m.group('mm')), int(m.group('dd'))
                clock = m.group('clock').decode('ascii')
                hour, minute, second = map(int, clock[:8].split(':'))
                if not (1 <= mm <= 12 and 1 <= dd <= 31 and hour <= 23 and minute <= 59 and second <= 59):
                    raise IntegrityError(f'{label}: invalid timestamp at line {lineno}')
                local = f'{mm:02d}-{dd:02d} {clock}'
                if previous is not None and local < previous:
                    counts['timestamp_regressions'] += 1
                previous = local
                counts['yearless_timestamp_lines'] += 1
            matched = [name for name, pattern in PATTERNS.items() if pattern.search(line)]
            for name in matched:
                counts[name] += 1
            if matched:
                parsed.append({
                    'source': label, 'source_line': lineno,
                    'source_line_sha256': hashlib.sha256(line).hexdigest(),
                    'source_timestamp': (m.group(0).strip().decode('ascii') if m else None),
                    'clock_basis': 'SOURCE_LOCAL_YEARLESS_TIMEZONE_UNKNOWN',
                    'classifications': matched,
                    'confidence': 'CANDIDATE_UNVERIFIED',
                    'semantic_event': 'NOT_ESTABLISHED',
                    'raw_content_included': False,
                })
    if h.hexdigest() != expected_sha:
        raise IntegrityError(f'{label}: SHA256_MISMATCH')
    if counts['total_lines'] != expected_lines:
        raise IntegrityError(f'{label}: LINE_COUNT_MISMATCH')
    # Do not silently suppress nonmatching source lines.
    if counts['unparsed_timestamp_lines'] != 1:
        raise IntegrityError(f'{label}: TIMESTAMP_COVERAGE_MISMATCH')
    return {'source': label, 'source_sha256': expected_sha, 'counts': dict(sorted(counts.items())),
            'candidate_count': len(parsed), 'candidate_events': parsed,
            'root_cause': 'UNKNOWN', 'validation_vs_bearer_order': 'NOT_ESTABLISHED',
            'device_qualification': 'NOT_EXECUTED'}

def run(sources=SOURCES):
    # Fail all-or-nothing; results aren't emitted until every hash qualifies.
    return {'contract': 'N1I_H1_B2_CANDIDATES_V1',
            'semantic_interpretation': 'NOT_AUTHORIZED_WITHOUT_LINE_PATTERN_REVIEW',
            'source_timezones': 'UNKNOWN', 'sources': [read_source(k, Path(v[0]), v[1], v[2])
                                                    for k, v in sources.items()]}

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--summary-only', action='store_true', help='Omit line-level candidate records from stdout')
    args = ap.parse_args()
    try:
        obj = run()
    except (IntegrityError, OSError) as e:
        print(json.dumps({'status': 'HOLD', 'reason': str(e), 'device_contact': 'NOT_EXECUTED'}))
        return 2
    if args.summary_only:
        for src in obj['sources']:
            src.pop('candidate_events')
    print(json.dumps(obj, sort_keys=True, separators=(',', ':')))
    return 0
if __name__ == '__main__':
    raise SystemExit(main())
