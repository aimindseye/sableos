#!/usr/bin/env python3
"""H1-C2: offline cross-run coverage supplement; no evidence writes/device/network.

Signature sightings are diagnostics, NOT confirmed phone/subscription events.
"""
import argparse
import hashlib
import json
import re
import stat
from pathlib import Path
import n1i_h1b6 as B6
import n1i_h1c1 as C1

N1H = None
OPERATOR_SNAPSHOTS = None
SNAPSHOTS = {
    'start.connectivity.txt': (43711, 'b78cd0ba1cbb5bb39f27b5f10f19f6b495304506055dcb987ae465d155bb98fd'),
    'end.connectivity.txt': (43699, 'cc81052ff3a64d2a91670f3eec871bbdbbb2e094ef90025c4c72e7280b43a574'),
    'start.telephony-registry.txt': (134915, 'ae15dff801dbdedeec990ce49b9a6f7cc583132090399222264478e5cd5f6825'),
    'end.telephony-registry.txt': (134916, '191a1ac676bcae31751844a4194d66d4c2155a433104d10317b957869416163d'),
    'start.carrier-config.txt': (55677, '6f7092a292d577e8bc4c432342005d2573bc90dd775430bf898b5ae553e8359a'),
    'end.carrier-config.txt': (55677, '6f7092a292d577e8bc4c432342005d2573bc90dd775430bf898b5ae553e8359a'),
}
SIGNATURES = {
    'DSRM_GET_DATA_CALL_LIST_TOKEN': re.compile(rb'GET_DATA_CALL_LIST', re.I),
    'DSRM_CONTEXT_TOKEN': re.compile(rb'DSRM|DataStallRecovery', re.I),
    'REGISTRATION_REJECT_TOKEN': re.compile(rb'reject(?:\s*|[_.-])cause|registration.*reject|reject.*registration', re.I),
    'DNS_CONTEXT_TOKEN': re.compile(rb'\bDNS\b|DnsResolver|dns_probe', re.I),
    'VALIDATION_CALLBACK_TOKEN': re.compile(rb'onInternetValidationStatusChanged', re.I),
}
SNAP_SIG = {
    'VALIDATED_TOKEN': re.compile(rb'\bVALIDATED\b'),
    'DEFAULT_NETWORK_TOKEN': re.compile(rb'default\s*(?:network|data)|mDefault', re.I),
    'DNS_TOKEN': re.compile(rb'\bdns\b|dnsServers', re.I),
    'REGISTRATION_TOKEN': re.compile(rb'registration|mServiceState', re.I),
}

def verified_file(path, size, sha):
    if path.is_symlink() or not path.is_file() or not stat.S_ISREG(path.stat().st_mode):
        raise B6.IntegrityError('SOURCE_NOT_REGULAR: '+path.name)
    raw = path.read_bytes()
    if len(raw) != size or hashlib.sha256(raw).hexdigest() != sha:
        raise B6.IntegrityError('SOURCE_HASH_OR_SIZE_MISMATCH: '+path.name)
    return raw

def scan(lines, signatures):
    """Count token-bearing lines, retaining hashes/indices, never raw values."""
    return {key: {'count': len(hits), 'line_refs': hits}
            for key, pattern in signatures.items()
            for hits in [[{'line': i, 'line_sha256': hashlib.sha256(line).hexdigest()}
                          for i, line in enumerate(lines, 1) if pattern.search(line)]]}

def analyze(raw_sources, snapshot_bytes, base_report):
    if base_report.get('contract') != 'N1I_H1_C1_CROSS_RUN_V1' or base_report.get('root_cause') != 'UNKNOWN':
        raise ValueError('INVALID_C1_REPORT')
    if set(raw_sources) != set(B6.SOURCES):
        raise ValueError('INVALID_RADIO_SOURCE_SET')
    failure = raw_sources['OCT09_N1F_FAILURE']
    post = raw_sources['OCT09_POST_CYCLE']
    if len(post) < len(failure) or post[:len(failure)] != failure:
        raise ValueError('OCT09_LINEAGE_PREFIX_MISMATCH')
    audit = {}
    for key in ('OCT03_N1H', 'OCT07_STOCK', 'OCT09_N1F_FAILURE'):
        audit[key] = scan(raw_sources[key], SIGNATURES)
    audit['OCT09_POST_CYCLE_CONTINUATION'] = scan(post[len(failure):], SIGNATURES)
    # Explicit per-source line-number provenance on the unique continuation.
    for value in audit['OCT09_POST_CYCLE_CONTINUATION'].values():
        for ref in value['line_refs']:
            ref['line'] += len(failure)
    snapshot_coverage = {}
    for name in SNAPSHOTS:
        if name not in snapshot_bytes:
            raise ValueError('MISSING_SNAPSHOT')
        entries = scan(snapshot_bytes[name].splitlines(keepends=True), SNAP_SIG)
        snapshot_coverage[name] = {'scope': 'POINT_IN_TIME_SNAPSHOT_NOT_CONTINUOUS',
                                   'signature_counts': {k: v['count'] for k, v in entries.items()},
                                   'content_semantics': 'UNREVIEWED_TOKEN_COUNTS'}
    discrepancies = {}
    for run in audit:
        b6_count = base_report['coverage'][run]['kind_counts']['DSRM_ACTION_SELECTED']
        observed = audit[run]['DSRM_GET_DATA_CALL_LIST_TOKEN']['count']
        discrepancies[run] = {'b6_selected_count': b6_count, 'raw_token_lines': observed,
                              'status': 'COUNT_DISCREPANCY_REVIEW_REQUIRED' if observed != b6_count else 'COUNTS_AGREE_TOKEN_NOT_EXECUTION'}
    return {'contract': 'N1I_H1_C2_COVERAGE_V1', 'root_cause': 'UNKNOWN',
            'source_scope': 'VERIFIED_RADIO_LOG_AND_N1H_SNAPSHOTS_ONLY',
            'raw_signature_audit': audit, 'dsrm_reconciliation': discrepancies,
            'n1h_snapshots': snapshot_coverage,
            'registration_reject_order': 'NOT_ESTABLISHED_TOKEN_ONLY',
            'dns_to_validation_order': 'NOT_ESTABLISHED_TOKEN_ONLY',
            'default_bearer_identity': 'NOT_ESTABLISHED',
            'post_cycle_validated_recovery': 'NOT_PROVEN',
            'stock_gsi_causal_comparability': 'NOT_ESTABLISHED',
            'snapshot_not_continuous': True,
            'classification': 'OFFLINE_COVERAGE_AUDIT_NOT_SEMANTIC_VERDICT'}

def summarize(report):
    out = dict(report)
    out['raw_signature_audit'] = {k: {s:v['count'] for s,v in vals.items()}
                                  for k,vals in report['raw_signature_audit'].items()}
    return out

def run():
    # Independently verify all source bytes before producing any report.
    raw = {key: B6.load_verified(key, spec) for key,spec in B6.SOURCES.items()}
    snaps = {name: verified_file(Path(OPERATOR_SNAPSHOTS[name]) if OPERATOR_SNAPSHOTS is not None else Path("/NONEXISTENT_MANIFEST_REQUIRED") / name, *spec) for name,spec in SNAPSHOTS.items()}
    report = C1.compare(B6.normalize({key:(lines,B6.SOURCES[key][1]) for key,lines in raw.items()}))
    return analyze(raw, snaps, report)

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--summary-only', action='store_true')
    args = ap.parse_args()
    try:
        report = run()
    except (B6.IntegrityError, ValueError, OSError, KeyError) as exc:
        print(json.dumps({'status':'HOLD','reason':str(exc),'root_cause':'UNKNOWN'}))
        return 2
    print(json.dumps(summarize(report) if args.summary_only else report, sort_keys=True, separators=(',',':')))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
