import hashlib
import unittest
import n1i_h1c2b as C


def mk(lines):
    return [(f'10-09 21:28:{i:02d}.000  1  1 D RmmNwHdlr: '+s+'\n').encode() for i,s in enumerate(lines)]

class H1C2BTests(unittest.TestCase):
    def test_selection_not_lastaction(self):
        a=mk(['[1] getRecoveryAction: RECOVERY_ACTION_GET_DATA_CALL_LIST',
              '[1] data stall: start, lastaction=RECOVERY_ACTION_GET_DATA_CALL_LIST'])
        out=C.classify(a,'S','a'*64)['dsrm']
        self.assertEqual([len(out[k]) for k in ('selected_refs','status_refs','ambiguous_refs')],[1,1,0])
        self.assertEqual(out['execution'],'NOT_ESTABLISHED')
    def test_unknown_token_not_selection(self):
        out=C.classify(mk(['GET_DATA_CALL_LIST unexpected']), 'S','a'*64)['dsrm']
        self.assertEqual(len(out['ambiguous_refs']),1)
        self.assertFalse(out['selected_refs'])
    def test_exact_ps_fields_not_cs(self):
        src=mk(['[1] [handlePsInd][handlePsNetworkStateChanged] stat=3, reject_cause=15',
                '[1] [handleCsInd][handleCsNetworkStateChanged] stat=3, reject_cause=13'])
        out=C.classify(src,'S','a'*64)
        self.assertEqual([x['reject_cause'] for x in out['ps_registration_indications']],[15])
        self.assertEqual(out['ps_registration_indications'][0]['phone_id'],1)
        self.assertEqual(out['ps_registration_indications'][0]['subscription'],'UNKNOWN')
    def test_zero_reject_not_failure(self):
        r=C.classify(mk(['[1] [handlePsInd][handlePsNetworkStateChanged] stat=1, reject_cause=0']),'S','a'*64)
        self.assertEqual(r['ps_registration_indications'][0]['reject_cause'],0)
    def test_no_inferred_phone(self):
        x=C.classify(mk(['[handlePsInd][handlePsNetworkStateChanged] reject_cause=11']),'S','a'*64)
        self.assertIsNone(x['ps_registration_indications'][0]['phone_id'])
    def test_sst_separate(self):
        x=C.classify(mk(['SST-1: mRejectCause=11']),'S','a'*64)
        self.assertEqual(len(x['sst_reject_fields']),1)
        self.assertEqual(len(x['ps_registration_indications']),0)
    def test_timestamps_and_line_offset(self):
        x=C.classify(mk(['getRecoveryAction: RECOVERY_ACTION_GET_DATA_CALL_LIST']),'POST','b'*64,7587)
        self.assertEqual(x['dsrm']['selected_refs'][0]['line'],7588)
        self.assertEqual(x['dsrm']['selected_refs'][0]['timestamp_local'],'2026-10-09T21:28:00.000000')
    def test_no_raw_text_output(self):
        x=C.classify(mk(['getRecoveryAction: RECOVERY_ACTION_GET_DATA_CALL_LIST']),'S','a'*64)
        self.assertNotIn('RmmNwHdlr',str(x))
    def test_prefix_rejected(self):
        raw={k: [b'line\n'] for k in C.B6.SOURCES}
        raw['OCT09_POST_CYCLE']=[b'different\n']
        with self.assertRaisesRegex(ValueError,'PREFIX'):
            C.evaluate(raw, {'contract':'N1I_H1_C2_COVERAGE_V1','root_cause':'UNKNOWN'})
    def test_provenance_rejected(self):
        with self.assertRaisesRegex(ValueError,'BAD_C2'):
            C.evaluate({}, {'contract':'OTHER','root_cause':'UNKNOWN'})
    def test_summary_removes_line_refs(self):
        obj={'contract':'x','segments':{'A':C.classify(mk(['getRecoveryAction: RECOVERY_ACTION_GET_DATA_CALL_LIST']),'A','a'*64)}}
        text=str(C.summarize(obj))
        self.assertNotIn('line_sha256',text)
        self.assertIn('dsrm_selected',text)

if __name__=='__main__': unittest.main()
