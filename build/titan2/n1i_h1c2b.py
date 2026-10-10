#!/usr/bin/env python3
"""N1I H1-C2B: fail-closed offline DSRM/PS-registration evidence repair.

Does not infer recovery execution, default subscription, DNS behavior or root cause.
Historical log input is verified by inherited H1-C2 before analysis.
"""
import argparse
from pathlib import Path
import hashlib
import json
import re
from datetime import datetime

import n1i_h1b6 as B6
import n1i_h1c2 as C2

SELECT = re.compile(rb'\bgetRecoveryAction\s*:\s*RECOVERY_ACTION_GET_DATA_CALL_LIST\b', re.I)
TOKEN = re.compile(rb'GET_DATA_CALL_LIST', re.I)
STATUS = re.compile(rb'\blastaction\s*=\s*RECOVERY_ACTION_GET_DATA_CALL_LIST\b', re.I)
# Only packet-service *indication* fields qualify; CS reject causes are excluded.
PS_IND = re.compile(rb'\[handlePsInd\]\[handlePsNetworkStateChanged\]', re.I)
PS_CODE = re.compile(rb'\breject_cause\s*=\s*(\d{1,5})\b', re.I)
PS_STATE = re.compile(rb'\bstat\s*=\s*(\d{1,3})\b', re.I)
RMM_PHONE = re.compile(rb'RmmNwHdlr:\s*\[(\d{1,2})\]', re.I)
SST_REJECT = re.compile(rb'\b(?:mRejectCause|rejectCause)\s*[:=]\s*(\d{1,5})\b', re.I)


def ref(label, sha, idx, line):
    return {'source': label, 'source_sha256': sha, 'line': idx,
            'line_sha256': hashlib.sha256(line).hexdigest(),
            'timestamp_local': B6.decode_time(line)}


def classify(lines, label, sha, offset=0):
    selection, status, ambiguous, ps, sst = [], [], [], [], []
    for i, line in enumerate(lines, 1):
        r = ref(label, sha, i + offset, line)
        has_token = TOKEN.search(line) is not None
        if has_token:
            if SELECT.search(line):
                selection.append(r)
            elif STATUS.search(line):
                status.append(r)
            else:
                ambiguous.append(r)
        if PS_IND.search(line):
            m, state, phone = PS_CODE.search(line), PS_STATE.search(line), RMM_PHONE.search(line)
            if m:
                ps.append({**r, 'reject_cause': int(m.group(1)),
                           'ps_stat': int(state.group(1)) if state else None,
                           'phone_id': int(phone.group(1)) if phone else None,
                           'subscription': 'UNKNOWN',
                           'classification': 'OBSERVED_PS_INDICATION_FIELD_NOT_NEW_REJECT_EVENT'})
        else:
            # Report SST-only candidates separately, without treating PS/CS fields as equivalent.
            m = SST_REJECT.search(line)
            if m:
                sst.append({**r, 'reject_cause': int(m.group(1)),
                            'classification': 'SST_REJECT_FIELD_UNCORRELATED'})
    return {'dsrm': {'selected_refs': selection, 'status_refs': status,
                     'ambiguous_refs': ambiguous, 'execution': 'NOT_ESTABLISHED'},
            'ps_registration_indications': ps, 'sst_reject_fields': sst}


def evaluate(raw, c2_report):
    if c2_report.get('contract') != 'N1I_H1_C2_COVERAGE_V1' or c2_report.get('root_cause') != 'UNKNOWN':
        raise ValueError('BAD_C2_PROVENANCE')
    if set(raw) != set(B6.SOURCES):
        raise ValueError('SOURCE_SET_MISMATCH')
    failure, post = raw['OCT09_N1F_FAILURE'], raw['OCT09_POST_CYCLE']
    if len(post) < len(failure) or post[:len(failure)] != failure:
        raise ValueError('OCT09_PREFIX_MISMATCH')
    segments = {k: (raw[k], 0, k) for k in ('OCT03_N1H','OCT07_STOCK','OCT09_N1F_FAILURE')}
    segments['OCT09_POST_CYCLE_CONTINUATION'] = (post[len(failure):], len(failure), 'OCT09_POST_CYCLE')
    results = {}
    for key, (lines, off, source) in segments.items():
        sha = B6.SOURCES[source][1]
        result = classify(lines, source, sha, off)
        dsrm = result['dsrm']
        audit_count = c2_report['raw_signature_audit'][key]['DSRM_GET_DATA_CALL_LIST_TOKEN']['count']
        observed = sum(len(dsrm[k]) for k in ('selected_refs','status_refs','ambiguous_refs'))
        if observed != audit_count:
            raise ValueError('DSRM_AUDIT_DISAGREES_'+key)
        results[key] = result
    return {'contract': 'N1I_H1_C2B_SEMANTIC_REPAIR_V1',
            'qualification': 'OFFLINE_FIELDS_AND_SELECTIONS_NOT_CAUSAL_VERDICT',
            'root_cause':'UNKNOWN', 'default_subscription':'UNKNOWN',
            'dns_to_validation_order':'NOT_ESTABLISHED',
            'dsrm_execution':'NOT_ESTABLISHED',
            'registration_reject_order':'FIELD_OBSERVATIONS_ONLY_NO_NEW_EVENT_DEDUP',
            'snapshot_scope':'POINT_IN_TIME_UNREVIEWED_SEMANTICS',
            'post_cycle_validated_recovery':'NOT_PROVEN',
            'shared_prefix_lines':len(failure), 'continuation_lines':len(post)-len(failure),
            'segments':results}


def summarize(report):
    out = {k: v for k, v in report.items() if k != 'segments'}
    out['segments'] = {}
    for key, seg in report['segments'].items():
        d = seg['dsrm']
        out['segments'][key] = {
            'dsrm_selected': len(d['selected_refs']),
            'dsrm_status_not_selection': len(d['status_refs']),
            'dsrm_ambiguous': len(d['ambiguous_refs']),
            'dsrm_execution':'NOT_ESTABLISHED',
            'ps_indications_with_reject_field':len(seg['ps_registration_indications']),
            'ps_indications_nonzero_reject_field':sum(x['reject_cause'] != 0 for x in seg['ps_registration_indications']),
            'sst_reject_fields':len(seg['sst_reject_fields']),
            'registered_event_order':'NOT_ESTABLISHED_FROM_FIELD_COUNTS'}
    return out


def run():
    raw = {key: B6.load_verified(key, spec) for key,spec in B6.SOURCES.items()}
    snapshots = {name: C2.verified_file(Path(C2.OPERATOR_SNAPSHOTS[name]) if C2.OPERATOR_SNAPSHOTS is not None else Path("/NONEXISTENT_MANIFEST_REQUIRED") / name, *spec) for name,spec in C2.SNAPSHOTS.items()}
    c1 = C2.C1.compare(B6.normalize({k:(v,B6.SOURCES[k][1]) for k,v in raw.items()}))
    c2 = C2.analyze(raw,snapshots,c1)
    return evaluate(raw,c2)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--summary-only', action='store_true')
    args = ap.parse_args()
    try:
        report = run()
    except (B6.IntegrityError, ValueError, KeyError, OSError) as exc:
        print(json.dumps({'status':'HOLD','reason':str(exc),'root_cause':'UNKNOWN'}))
        return 2
    print(json.dumps(summarize(report) if args.summary_only else report,sort_keys=True,separators=(',',':')))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
