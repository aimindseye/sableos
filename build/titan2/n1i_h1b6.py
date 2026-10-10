#!/usr/bin/env python3
"""N1I H1-B6 offline semantic evidence normalizer. NO writes, device, network or subprocess.

This is a conservative log-level extractor, NOT a v1.2 validated-mobile verdict.
"""
import argparse
import hashlib
import json
import re
import stat
from datetime import datetime
from pathlib import Path

from n1i_h1b2 import SOURCES, IntegrityError

STAMP = re.compile(rb'^\s*(\d\d-\d\d \d\d:\d\d:\d\d\.\d{3,6})\b')
EVENT_RULES = (
    ('VALIDATION_INVALID_CALLBACK', re.compile(rb'\bonInternetValidationStatusChanged\b[^\r\n]{0,160}\bINVALID\b', re.I)),
    ('VALIDATION_VALID_CALLBACK', re.compile(rb'\bonInternetValidationStatusChanged\b[^\r\n]{0,160}\bVALID\b', re.I)),
    ('DSRM_ACTION_SELECTED', re.compile(rb'\bGET_DATA_CALL_LIST\b', re.I)),
    ('VENDOR_DEACT_INDICATION', re.compile(rb'\bDATA_DEACT_CALL_IND\b', re.I)),
    ('VENDOR_DEACT_CALLBACK', re.compile(rb'\bonDataCallDeact\b', re.I)),
    ('VENDOR_NETWORK_CAUSE', re.compile(rb'\bNETWORK CAUSE\b', re.I)),
    ('DATA_CALL_ERROR', re.compile(rb'\bERROR_UNSPECIFIED\b', re.I)),
)
CID = re.compile(rb'\bcid\s*[:=]\s*(\d{1,3})\b', re.I)
ACTIVE = re.compile(rb'\bactive\s*[:=]\s*([012])\b', re.I)
RESULT = re.compile(rb'\bres\s*[:=]\s*(\d{1,10})\b', re.I)
HEX = re.compile(rb'\b0x([a-fA-F0-9]{1,8})\b')
PHONE = re.compile(rb'\bphoneId\s*[:=]\s*(\d{1,2})\b', re.I)
# No inferred SIM subscription, default data, internet CID, registration, or recovery execution.


def load_verified(label, spec):
    path, sha, count = spec
    p = Path(path)
    if p.is_symlink() or not p.is_file() or not stat.S_ISREG(p.stat().st_mode):
        raise IntegrityError(f'{label}: SOURCE_NOT_REGULAR')
    raw = p.read_bytes()
    if hashlib.sha256(raw).hexdigest() != sha:
        raise IntegrityError(f'{label}: SHA256_MISMATCH')
    lines = raw.splitlines(keepends=True)
    if len(lines) != count:
        raise IntegrityError(f'{label}: LINE_COUNT_MISMATCH')
    return lines


def decode_time(raw):
    m = STAMP.match(raw)
    if not m:
        return None
    try:
        return datetime.strptime('2026-' + m.group(1).decode('ascii'), '%Y-%m-%d %H:%M:%S.%f').isoformat(timespec='microseconds')
    except ValueError:
        raise IntegrityError('INVALID_TIMESTAMP') from None


def field(pattern, raw):
    m = pattern.search(raw)
    return int(m.group(1)) if m else None


def extract(lines, label, full_sha, line_offset=0):
    events, regression_lines = [], []
    previous = None
    missing = 0
    for idx, raw in enumerate(lines, 1):
        lineno = line_offset + idx
        t = decode_time(raw)
        if t is None:
            missing += 1
        elif previous is not None and t < previous:
            regression_lines.append(lineno)
        if t is not None:
            previous = t
        kinds = [name for name, pattern in EVENT_RULES if pattern.search(raw)]
        active, cid = field(ACTIVE, raw), field(CID, raw)
        # Active fields are only recorded as explicit state, not attributed internet CID.
        if active is not None and 'DATA_CALL_STATE_FIELD' not in kinds:
            kinds.append('DATA_CALL_STATE_FIELD')
        if not kinds:
            continue
        fields = {'cid': cid, 'active': active, 'vendor_result_decimal': None,
                  'vendor_cause_hex': None, 'phone_id': field(PHONE, raw)}
        if 'VENDOR_DEACT_CALLBACK' in kinds:
            fields['vendor_result_decimal'] = field(RESULT, raw)
        if 'VENDOR_NETWORK_CAUSE' in kinds:
            m = HEX.search(raw)
            fields['vendor_cause_hex'] = '0x' + m.group(1).decode('ascii').upper() if m else None
        events.append({'source': label, 'line': lineno, 'source_sha256': full_sha,
                       'line_sha256': hashlib.sha256(raw).hexdigest(),
                       'timestamp_local': t, 'clock_timezone': 'UNKNOWN',
                       'kinds': kinds, 'fields': fields,
                       'default_data_subscription': 'UNKNOWN',
                       'internet_bearer_attribution': 'NOT_ESTABLISHED'})
    return {'events': events, 'timestamp_regression_lines': regression_lines,
            'unparsed_timestamp_lines': missing}


def normalize(lineages):
    """lineages: {name: (list[bytes], expected SHA)}; verified by caller or synthetic fixture."""
    required = {'OCT03_N1H','OCT07_STOCK','OCT09_N1F_FAILURE','OCT09_POST_CYCLE'}
    if set(lineages) != required:
        raise IntegrityError('SOURCE_SET_MISMATCH')
    failure, post = lineages['OCT09_N1F_FAILURE'][0], lineages['OCT09_POST_CYCLE'][0]
    if len(post) < len(failure) or post[:len(failure)] != failure:
        raise IntegrityError('OCT09_PREFIX_MISMATCH')
    # Timestamp and line references in continuation are original post-cycle file line numbers.
    outputs = {}
    for label in ('OCT03_N1H', 'OCT07_STOCK', 'OCT09_N1F_FAILURE'):
        lines, sha = lineages[label]
        outputs[label] = extract(lines, label, sha)
    postsha = lineages['OCT09_POST_CYCLE'][1]
    continuation = extract(post[len(failure):], 'OCT09_POST_CYCLE', postsha, len(failure))
    outputs['OCT09_POST_CYCLE_CONTINUATION'] = continuation
    failures = outputs['OCT09_N1F_FAILURE']['events']
    val = [e for e in failures if 'VALIDATION_INVALID_CALLBACK' in e['kinds'] and e['timestamp_local']]
    deact = [e for e in failures if 'VENDOR_DEACT_INDICATION' in e['kinds'] and e['timestamp_local']]
    order = 'NOT_ESTABLISHED'
    if val and deact:
        order = 'CALLBACK_PRECEDES_VENDOR_INDICATION' if min(x['timestamp_local'] for x in val) < min(x['timestamp_local'] for x in deact) else 'NOT_PRECEDING'
    return {'contract': 'N1I_H1_B6_SEMANTIC_V1', 'evidence_scope': 'RADIO_LOG_ANCHORS_ONLY',
            'clock_basis': 'SOURCE_LOCAL_2026_TIMEZONE_UNKNOWN',
            'root_cause': 'UNKNOWN', 'default_internet_bearer': 'NOT_ESTABLISHED',
            'dsrm_execution': 'NOT_ESTABLISHED', 'post_cycle_validated_recovery': 'NOT_PROVEN',
            'oct09_overlap': {'shared_prefix_lines': len(failure), 'continuation_lines': len(post)-len(failure), 'exact_prefix': True},
            'oct09_callback_vendor_order': order, 'sources': outputs}


def run(sources=SOURCES):
    # No JSON output until all four inputs have passed SHA and line-count verification.
    verified = {label: (load_verified(label, spec), spec[1]) for label, spec in sources.items()}
    return normalize(verified)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--summary-only', action='store_true')
    args = parser.parse_args()
    try:
        obj = run()
    except (IntegrityError, OSError) as exc:
        print(json.dumps({'status': 'HOLD', 'reason': str(exc), 'root_cause': 'UNKNOWN'}))
        return 2
    if args.summary_only:
        for src in obj['sources'].values():
            src['typed_event_count'] = len(src.pop('events'))
    print(json.dumps(obj, sort_keys=True, separators=(',', ':')))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
