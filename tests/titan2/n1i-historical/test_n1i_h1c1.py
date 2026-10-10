"""Synthetic, offline H1-C1 comparator regressions."""
import copy
import unittest

import n1i_h1b6 as B6
import n1i_h1c1 as C1
from test_n1i_h1b6 import bundle, line


class H1C1Tests(unittest.TestCase):
    def make(self):
        return B6.normalize(bundle())

    def test_report_and_overlap(self):
        r=C1.compare(self.make())
        self.assertEqual(r['shared_prefix_lines'],6)
        self.assertEqual(r['post_cycle_incremental_lines'],1)
        self.assertEqual(r['coverage']['OCT09_POST_CYCLE_CONTINUATION']['typed_event_lines'],1)
        self.assertEqual(r['root_cause'],'UNKNOWN')

    def test_validation_vendor_order_not_cause(self):
        r=C1.compare(self.make())
        self.assertEqual(r['oct09_chronology']['status'],'VALIDATION_CALLBACK_PRECEDES_VENDOR_INDICATION')
        self.assertAlmostEqual(r['oct09_chronology']['seconds_before_vendor'],52.547)
        self.assertEqual(r['oct09_chronology']['causal_interpretation'],'NOT_AUTHORIZED')

    def test_missing_callback_not_established(self):
        x=bundle(failure=[line('28:53.124','DATA_DEACT_CALL_IND')])
        self.assertEqual(C1.compare(B6.normalize(x))['oct09_chronology']['status'],'NOT_ESTABLISHED')

    def test_unknown_settings_not_guessed(self):
        r=C1.compare(self.make())
        self.assertTrue(all(v=='UNKNOWN_NOT_EXTRACTED_FROM_RADIO_LOG' for v in r['coverage']['OCT07_STOCK']['configuration'].values()))
        self.assertEqual(r['comparison']['default_bearer_attribution'],'NOT_ESTABLISHED')

    def test_dsrm_selection_not_execution(self):
        r=C1.compare(self.make())
        self.assertEqual(r['coverage']['OCT09_N1F_FAILURE']['kind_counts']['DSRM_ACTION_SELECTED'],1)
        self.assertEqual(r['comparison']['dsrm_execution'],'NOT_ESTABLISHED')

    def test_duplicate_prefix_event_rejected(self):
        obj=self.make()
        obj['sources']['OCT09_POST_CYCLE_CONTINUATION']['events'][0]['line']=1
        with self.assertRaisesRegex(ValueError,'DUPLICATE_PREFIX_EVENT'):C1.compare(obj)

    def test_duplicate_event_line_rejected(self):
        obj=self.make()
        obj['sources']['OCT09_N1F_FAILURE']['events'].append(copy.deepcopy(obj['sources']['OCT09_N1F_FAILURE']['events'][0]))
        with self.assertRaisesRegex(ValueError,'DUPLICATE_EVENT_LINE'):C1.compare(obj)

    def test_broken_contract_rejected(self):
        obj=self.make();obj['contract']='BAD'
        with self.assertRaisesRegex(ValueError,'INVALID_B6_CONTRACT'):C1.compare(obj)

    def test_bad_kind_rejected(self):
        obj=self.make();obj['sources']['OCT09_N1F_FAILURE']['events'][0]['kinds']=['INVENTED_CAUSE']
        with self.assertRaisesRegex(ValueError,'UNREVIEWED_EVENT_KIND'):C1.compare(obj)

    def test_unknown_verdict_rejected(self):
        obj=self.make();obj['root_cause']='MODEM'
        with self.assertRaisesRegex(ValueError,'UNSUPPORTED_CAUSAL_VERDICT'):C1.compare(obj)

    def test_summary_omits_line_level(self):
        r=C1.summarize(C1.compare(self.make()))
        self.assertNotIn('sequences',r)
        self.assertNotIn('validation_refs',r['oct09_chronology'])

    def test_stock_not_same_cause(self):
        r=C1.compare(self.make())
        self.assertEqual(r['comparison']['vendor_mechanism_equivalence'],'NOT_ESTABLISHED')
        self.assertEqual(r['comparison']['stock_gsi_causal_comparability'],'NOT_ESTABLISHED')


if __name__=='__main__':
    unittest.main()
