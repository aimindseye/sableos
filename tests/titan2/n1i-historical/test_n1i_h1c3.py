import copy
import unittest
import n1i_h1c3 as H


def fixtures():
    segments = {k: {'dsrm': {'selected_refs': [], 'status_refs': [], 'ambiguous_refs': []}, 'ps_registration_indications': []} for k in H.EXPECTED_KEYS}
    segments['OCT09_N1F_FAILURE']['dsrm']['selected_refs'] = [1, 2, 3, 4]
    segments['OCT09_N1F_FAILURE']['dsrm']['status_refs'] = [5, 6]
    segments['OCT09_POST_CYCLE_CONTINUATION']['dsrm']['selected_refs'] = [7, 8, 9]
    return (
        {'contract': 'N1I_H1_C1_CROSS_RUN_V1', 'root_cause': 'UNKNOWN', 'shared_prefix_lines': 7587,
         'post_cycle_incremental_lines': 1482, 'oct09_chronology': {'status': 'VALIDATION_CALLBACK_PRECEDES_VENDOR_INDICATION', 'seconds_before_vendor': 52.547},
         'coverage': {k: {'source_evidence_scope': 'RADIO_LOG_ONLY', 'configuration': {}} for k in H.EXPECTED_KEYS},
         'unresolved_questions': ['Which network was validated?']},
        {'contract': 'N1I_H1_C2B_SEMANTIC_REPAIR_V1', 'root_cause': 'UNKNOWN', 'shared_prefix_lines': 7587,
         'continuation_lines': 1482, 'dsrm_execution': 'NOT_ESTABLISHED', 'default_subscription': 'UNKNOWN',
         'post_cycle_validated_recovery': 'NOT_PROVEN', 'segments': segments})

class H1C3Tests(unittest.TestCase):
    def test_report(self):
        c1, c2 = fixtures(); r = H.combine(c1, c2)
        self.assertEqual(r['dsrm']['OCT09_N1F_FAILURE']['selected'], 4)
        self.assertEqual(r['dsrm']['OCT09_POST_CYCLE_CONTINUATION']['selected'], 3)
        self.assertEqual(r['root_cause'], 'UNKNOWN')
    def test_no_raw_refs_in_summary(self):
        a,b=fixtures(); self.assertNotIn('selected_refs', str(H.combine(a,b)))
    def test_prefix_mismatch_holds(self):
        a,b=fixtures();b['shared_prefix_lines']=1
        with self.assertRaises(ValueError):H.combine(a,b)
    def test_causality_holds(self):
        a,b=fixtures();a['root_cause']='PROVEN'
        with self.assertRaises(ValueError):H.combine(a,b)
    def test_bad_dsrm_execution_holds(self):
        a,b=fixtures();b['dsrm_execution']='EXECUTED'
        with self.assertRaises(ValueError):H.combine(a,b)
    def test_unknown_default_holds(self):
        a,b=fixtures();b['default_subscription']='S1'
        with self.assertRaises(ValueError):H.combine(a,b)
    def test_bad_contract_holds(self):
        a,b=fixtures();a['contract']='UNKNOWN'
        with self.assertRaises(ValueError):H.combine(a,b)
    def test_not_proven_recovery_holds(self):
        a,b=fixtures();b['post_cycle_validated_recovery']='PROVEN'
        with self.assertRaises(ValueError):H.combine(a,b)
    def test_missing_segment_holds(self):
        a,b=fixtures();del b['segments']['OCT07_STOCK']
        with self.assertRaises(ValueError):H.combine(a,b)
    def test_no_guessed_dns(self):
        a,b=fixtures();r=H.combine(a,b)
        self.assertEqual(r['dns_failure_order'],'NOT_ESTABLISHED')

if __name__=='__main__':unittest.main()
