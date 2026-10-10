"""Synthetic H1-C2 coverage audit regression tests. No historical sources read."""
import hashlib
import unittest
import n1i_h1b6 as B6
import n1i_h1c1 as C1
import n1i_h1c2 as C2

def line(msg):
    return ('10-09 21:28:00.001 123 456 I TAG: '+msg+'\n').encode()

def fixture():
    main=[line('onInternetValidationStatusChanged INVALID'),line('DSRM GET_DATA_CALL_LIST selected'),
          line('DATA_DEACT_CALL_IND'),line('registration reject cause:15'),line('dns_probe failure')]
    tail=[line('onInternetValidationStatusChanged INVALID')]
    def entry(lines):return (lines, hashlib.sha256(b''.join(lines)).hexdigest())
    values={'OCT03_N1H':entry([line('REGISTRATION state')]),'OCT07_STOCK':entry([line('DATA_DEACT_CALL_IND')]),
            'OCT09_N1F_FAILURE':entry(main),'OCT09_POST_CYCLE':entry(main+tail)}
    report=C1.compare(B6.normalize(values))
    snaps={k:b'VALIDATED DNS default network registration\n' for k in C2.SNAPSHOTS}
    return {k:v[0] for k,v in values.items()},snaps,report

class H1C2Tests(unittest.TestCase):
    def test_token_not_execution(self):
        raw,snaps,base=fixture(); out=C2.analyze(raw,snaps,base)
        self.assertEqual(out['raw_signature_audit']['OCT09_N1F_FAILURE']['DSRM_GET_DATA_CALL_LIST_TOKEN']['count'],1)
        self.assertNotIn('EXECUTED',out['dsrm_reconciliation']['OCT09_N1F_FAILURE']['status'])
    def test_anchor_discrepancy_detected(self):
        raw,snaps,base=fixture();base['coverage']['OCT09_N1F_FAILURE']['kind_counts']['DSRM_ACTION_SELECTED']=0
        self.assertEqual(C2.analyze(raw,snaps,base)['dsrm_reconciliation']['OCT09_N1F_FAILURE']['status'],'COUNT_DISCREPANCY_REVIEW_REQUIRED')
    def test_no_inferred_dns_or_reject_order(self):
        raw,snaps,base=fixture();out=C2.analyze(raw,snaps,base)
        self.assertEqual(out['registration_reject_order'],'NOT_ESTABLISHED_TOKEN_ONLY')
        self.assertEqual(out['dns_to_validation_order'],'NOT_ESTABLISHED_TOKEN_ONLY')
    def test_snapshots_not_continuous(self):
        raw,snaps,base=fixture();out=C2.analyze(raw,snaps,base)
        self.assertTrue(out['snapshot_not_continuous'])
        self.assertTrue(all(v['scope']=='POINT_IN_TIME_SNAPSHOT_NOT_CONTINUOUS' for v in out['n1h_snapshots'].values()))
    def test_prefix_conflict_holds(self):
        raw,snaps,base=fixture();raw['OCT09_POST_CYCLE'][0]=b'tampered\n'
        with self.assertRaisesRegex(ValueError,'PREFIX_MISMATCH'):C2.analyze(raw,snaps,base)
    def test_continuation_line_ref_offset(self):
        raw,snaps,base=fixture();out=C2.analyze(raw,snaps,base)
        self.assertEqual(out['raw_signature_audit']['OCT09_POST_CYCLE_CONTINUATION']['VALIDATION_CALLBACK_TOKEN']['line_refs'][0]['line'],6)
    def test_summary_omits_line_hashes(self):
        raw,snaps,base=fixture();out=C2.summarize(C2.analyze(raw,snaps,base))
        self.assertNotIn('line_refs',str(out))
    def test_missing_snapshot_holds(self):
        raw,snaps,base=fixture();snaps.pop('start.connectivity.txt')
        with self.assertRaisesRegex(ValueError,'MISSING_SNAPSHOT'):C2.analyze(raw,snaps,base)
    def test_bad_report_holds(self):
        raw,snaps,base=fixture();base['root_cause']='PROVEN'
        with self.assertRaisesRegex(ValueError,'INVALID_C1_REPORT'):C2.analyze(raw,snaps,base)
    def test_cannot_promote_causality(self):
        raw,snaps,base=fixture();out=C2.analyze(raw,snaps,base)
        self.assertEqual(out['root_cause'],'UNKNOWN')
        self.assertEqual(out['stock_gsi_causal_comparability'],'NOT_ESTABLISHED')

if __name__=='__main__': unittest.main()
