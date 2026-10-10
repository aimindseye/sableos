#!/usr/bin/env python3
"""N1I H1-C1 offline historical comparator; read-only, conservative, no root-cause inference."""
import argparse
import json
from collections import Counter
from datetime import datetime

import n1i_h1b6 as B6

GROUPS = {
    'OCT03_N1H': 'GSI_BASELINE',
    'OCT07_STOCK': 'STOCK_CONTROL',
    'OCT09_N1F_FAILURE': 'GSI_FAILURE',
    'OCT09_POST_CYCLE_CONTINUATION': 'GSI_POST_CYCLE_CONTINUATION',
}
RUN_ORDER = tuple(GROUPS)
KINDS = ('VALIDATION_INVALID_CALLBACK','VALIDATION_VALID_CALLBACK','DSRM_ACTION_SELECTED',
         'VENDOR_DEACT_INDICATION','VENDOR_DEACT_CALLBACK','VENDOR_NETWORK_CAUSE',
         'DATA_CALL_ERROR','DATA_CALL_STATE_FIELD')
UNKNOWN_FIELDS = ('apn_name','apn_protocol','apn_roaming_protocol','dns_servers',
                  'private_dns_mode','connectivity_check_source','connectivity_check_urls',
                  'sim_tray','default_data_subscription','internet_bearer_cid',
                  'operator_config','capture_duration')


def _refs(events, kind):
    return [{'source':e['source'],'line':e['line'], 'source_sha256':e['source_sha256'],
             'line_sha256':e['line_sha256'], 'timestamp_local':e['timestamp_local']}
            for e in events if kind in e['kinds']]


def _time(e):
    return datetime.fromisoformat(e['timestamp_local'])


def compare(normalized):
    if normalized.get('contract') != 'N1I_H1_B6_SEMANTIC_V1':
        raise ValueError('INVALID_B6_CONTRACT')
    sources = normalized.get('sources', {})
    if set(sources) != set(RUN_ORDER):
        raise ValueError('INVALID_SOURCE_SET')
    overlap = normalized.get('oct09_overlap', {})
    if overlap.get('exact_prefix') is not True or not isinstance(overlap.get('shared_prefix_lines'),int):
        raise ValueError('PREFIX_NOT_VERIFIED')
    if normalized.get('root_cause') != 'UNKNOWN':
        raise ValueError('UNSUPPORTED_CAUSAL_VERDICT')
    coverage, sequences = {}, {}
    for label in RUN_ORDER:
        src = sources[label]
        events = src.get('events')
        if not isinstance(events,list):
            raise ValueError('MISSING_TYPED_EVENTS')
        seen = set()
        counts = Counter()
        seq = []
        for event in events:
            if event.get('source') != ('OCT09_POST_CYCLE' if label.endswith('CONTINUATION') else label):
                raise ValueError('EVENT_SOURCE_MISMATCH')
            if not isinstance(event.get('line'),int) or event['line'] < 1 or not isinstance(event.get('line_sha256'),str):
                raise ValueError('EVENT_PROVENANCE_INCOMPLETE')
            identity = (event['source'],event['line'])
            if identity in seen:
                raise ValueError('DUPLICATE_EVENT_LINE')
            seen.add(identity)
            if label.endswith('CONTINUATION') and event['line'] <= overlap['shared_prefix_lines']:
                raise ValueError('DUPLICATE_PREFIX_EVENT')
            kinds = event.get('kinds', [])
            if any(k not in KINDS for k in kinds):
                raise ValueError('UNREVIEWED_EVENT_KIND')
            counts.update(kinds)
            seq.append({'line':event['line'],'timestamp_local':event.get('timestamp_local'),
                        'kinds':kinds,'source_sha256':event.get('source_sha256'),
                        'line_sha256':event['line_sha256']})
        coverage[label] = {'classification': GROUPS[label], 'typed_event_lines':len(events),
                           'kind_counts':{k:counts[k] for k in KINDS},
                           'timestamp_regression_lines':src.get('timestamp_regression_lines'),
                           'unparsed_timestamp_lines':src.get('unparsed_timestamp_lines'),
                           'configuration': {k:'UNKNOWN_NOT_EXTRACTED_FROM_RADIO_LOG' for k in UNKNOWN_FIELDS},
                           'source_evidence_scope':'RADIO_LOG_ONLY'}
        sequences[label] = seq
    failure = sources['OCT09_N1F_FAILURE']['events']
    invalid = [e for e in failure if 'VALIDATION_INVALID_CALLBACK' in e['kinds'] and e.get('timestamp_local')]
    deact = [e for e in failure if 'VENDOR_DEACT_INDICATION' in e['kinds'] and e.get('timestamp_local')]
    chronology = {'status':'NOT_ESTABLISHED','seconds_before_vendor':None,
                  'validation_refs':_refs(failure,'VALIDATION_INVALID_CALLBACK'),
                  'vendor_refs':_refs(failure,'VENDOR_DEACT_INDICATION'),
                  'causal_interpretation':'NOT_AUTHORIZED'}
    if invalid and deact:
        v, d = min(invalid,key=_time), min(deact,key=_time)
        delta = (_time(d)-_time(v)).total_seconds()
        chronology['seconds_before_vendor'] = delta
        chronology['status'] = 'VALIDATION_CALLBACK_PRECEDES_VENDOR_INDICATION' if delta > 0 else 'NOT_PRECEDING'
    # No inference about whether a default mobile bearer carried internet traffic.
    stock = coverage['OCT07_STOCK']['kind_counts']
    gsi = coverage['OCT09_N1F_FAILURE']['kind_counts']
    return {'contract':'N1I_H1_C1_CROSS_RUN_V1', 'root_cause':'UNKNOWN',
            'qualification':'OFFLINE_OBSERVATIONAL_ONLY', 'clock':'SOURCE_LOCAL_2026_TIMEZONE_UNKNOWN',
            'shared_prefix_lines':overlap['shared_prefix_lines'],
            'post_cycle_incremental_lines':overlap.get('continuation_lines'),
            'coverage':coverage, 'sequences':sequences, 'oct09_chronology':chronology,
            'comparison':{'stock_vendor_indications_observed':stock['VENDOR_DEACT_INDICATION'],
                          'gsi_vendor_indications_observed':gsi['VENDOR_DEACT_INDICATION'],
                          'vendor_mechanism_equivalence':'NOT_ESTABLISHED',
                          'stock_gsi_causal_comparability':'NOT_ESTABLISHED',
                          'registration_reject_order':'NOT_EXTRACTED',
                          'dns_failure_order':'NOT_EXTRACTED',
                          'default_bearer_attribution':'NOT_ESTABLISHED',
                          'dsrm_execution':'NOT_ESTABLISHED',
                          'post_cycle_validated_recovery':'NOT_PROVEN'},
            'unresolved_questions':[
                'Are stock and GSI APN, IP protocol, SIM tray and operator configuration comparable?',
                'Which explicit identity evidence binds a data-call CID to the default internet subscription?',
                'Are validation callbacks associated with the same network as observed vendor deactivation?',
                'What is the semantic significance, if any, of opaque vendor causes?',
                'Can registry and connectivity snapshots establish additional validated-internet coverage?',
                'What are the exact registration reject sequences and their capture windows?',
            ]}


def summarize(report):
    data = dict(report)
    data.pop('sequences')
    data['oct09_chronology'] = dict(data['oct09_chronology'])
    data['oct09_chronology'].pop('validation_refs')
    data['oct09_chronology'].pop('vendor_refs')
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--summary-only',action='store_true')
    args = parser.parse_args()
    try:
        report = compare(B6.run())
    except (B6.IntegrityError, ValueError, OSError) as e:
        print(json.dumps({'status':'HOLD','reason':str(e),'root_cause':'UNKNOWN'}))
        return 2
    print(json.dumps(summarize(report) if args.summary_only else report,
                     sort_keys=True,separators=(',',':')))
    return 0

if __name__=='__main__':
    raise SystemExit(main())
