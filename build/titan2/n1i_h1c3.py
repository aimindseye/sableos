#!/usr/bin/env python3
"""N1I H1-C3 fail-closed offline unified summary. No device or network access."""
import argparse
import json
import sys

import n1i_h1b2 as B2
import n1i_h1c2 as C2
import n1i_h1_evidence_manifest as Manifest
import n1i_h1b6 as B6
import n1i_h1c1 as C1
import n1i_h1c2b as C2B

CONTRACT = 'N1I_H1_C3_UNIFIED_READINESS_V1'
EXPECTED_KEYS = ('OCT03_N1H', 'OCT07_STOCK', 'OCT09_N1F_FAILURE', 'OCT09_POST_CYCLE_CONTINUATION')


def combine(c1, c2b):
    """Integrate qualified reports without changing their evidence semantics."""
    if c1.get('contract') != 'N1I_H1_C1_CROSS_RUN_V1':
        raise ValueError('C1_CONTRACT_MISMATCH')
    if c2b.get('contract') != 'N1I_H1_C2B_SEMANTIC_REPAIR_V1':
        raise ValueError('C2B_CONTRACT_MISMATCH')
    if c1.get('root_cause') != 'UNKNOWN' or c2b.get('root_cause') != 'UNKNOWN':
        raise ValueError('UNSUPPORTED_ROOT_CAUSE')
    if c1.get('shared_prefix_lines') != c2b.get('shared_prefix_lines') or c1.get('post_cycle_incremental_lines') != c2b.get('continuation_lines'):
        raise ValueError('INCONSISTENT_OVERLAP')
    if set(c2b.get('segments', {})) != set(EXPECTED_KEYS):
        raise ValueError('SEGMENT_SET_MISMATCH')
    if c1.get('oct09_chronology', {}).get('status') != 'VALIDATION_CALLBACK_PRECEDES_VENDOR_INDICATION':
        raise ValueError('CHRONOLOGY_UNQUALIFIED')
    if c2b.get('dsrm_execution') != 'NOT_ESTABLISHED':
        raise ValueError('EXECUTION_UNSUPPORTED')
    if c2b.get('default_subscription') != 'UNKNOWN' or c2b.get('post_cycle_validated_recovery') != 'NOT_PROVEN':
        raise ValueError('ATTRIBUTION_UNSUPPORTED')
    selections = {}
    ps = {}
    for name in EXPECTED_KEYS:
        seg = c2b['segments'][name]
        dsrm = seg['dsrm']
        selections[name] = {'selected': len(dsrm['selected_refs']),
                            'status_only': len(dsrm['status_refs']),
                            'ambiguous': len(dsrm['ambiguous_refs']),
                            'execution': 'NOT_ESTABLISHED'}
        ps[name] = {'indications_with_field': len(seg['ps_registration_indications']),
                    'nonzero_reject_fields': sum(x['reject_cause'] != 0 for x in seg['ps_registration_indications']),
                    'interpretation': 'FIELD_OBSERVATIONS_NOT_DISTINCT_REJECT_EVENTS'}
    if selections['OCT09_N1F_FAILURE']['selected'] == 0 and selections['OCT09_N1F_FAILURE']['status_only'] > 0:
        raise ValueError('DSRM_SELECTION_COVERAGE_HOLD')
    return {
        'contract': CONTRACT,
        'qualification': 'OFFLINE_OBSERVATIONAL_INTEGRATION_ONLY',
        'root_cause': 'UNKNOWN',
        'source_clock': 'SOURCE_LOCAL_2026_TIMEZONE_UNKNOWN',
        'integrity': 'VERIFIED_BY_COMPONENT_READERS',
        'overlap': {'shared_prefix_lines': c1['shared_prefix_lines'],
                    'continuation_lines': c1['post_cycle_incremental_lines'],
                    'exact_prefix': True},
        'chronology': {'status': c1['oct09_chronology']['status'],
                       'seconds_before_vendor': c1['oct09_chronology']['seconds_before_vendor'],
                       'causal_interpretation': 'NOT_AUTHORIZED'},
        'dsrm': selections,
        'packet_service': ps,
        'coverage': {k: {'scope': v['source_evidence_scope'], 'configuration': v['configuration']}
                     for k, v in c1['coverage'].items()},
        'dns_failure_order': 'NOT_ESTABLISHED',
        'registration_event_order': 'NOT_ESTABLISHED_FROM_FIELD_OBSERVATIONS',
        'default_internet_bearer': 'NOT_ESTABLISHED',
        'validated_recovery': 'NOT_PROVEN',
        'stock_gsi_causal_comparability': 'NOT_ESTABLISHED',
        'snapshot_scope': 'POINT_IN_TIME_UNREVIEWED_SEMANTICS',
        'unresolved_questions': c1['unresolved_questions'],
        'repository_integration': 'PENDING_FULL_HOST_REGRESSION_AND_REVIEW',
    }


def run():
    b6 = B6.run()
    c1 = C1.compare(b6)
    c2b = C2B.run()
    return combine(c1, c2b)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--evidence-manifest', help='operator-only local JSON file')
    ap.add_argument('--summary-only', action='store_true', help='required safe output mode')
    args = ap.parse_args()
    if not args.summary_only:
        ap.error('only --summary-only is supported; raw evidence is never printed')
    try:
        Manifest.configure(args.evidence_manifest, B2, C2)
        result = run()
    except (ValueError, KeyError, OSError, B6.IntegrityError) as exc:
        print(json.dumps({'status': 'HOLD', 'reason': type(exc).__name__, 'root_cause': 'UNKNOWN'}, sort_keys=True))
        return 2
    print(json.dumps(result, sort_keys=True, separators=(',', ':')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
