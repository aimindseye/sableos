"""Offline synthetic tests; no retained evidence access required."""
import hashlib
import unittest
import n1i_h1b6 as n


def line(t, message):
    return f'10-09 21:{t} 123 456 I TAG: {message}\n'.encode()


def bundle(failure=None, tail=None):
    failure = failure if failure is not None else [
        line('28:00.577', 'onInternetValidationStatusChanged INVALID'),
        line('28:00.578', 'DSRM GET_DATA_CALL_LIST selected'),
        line('28:53.124', 'DATA_DEACT_CALL_IND'),
        line('28:53.128', 'onDataCallDeact aid:0 res:1314684'),
        line('28:53.130', 'NETWORK CAUSE 0x140F7C'),
        line('28:53.135', 'DataCall cid=101 active=0 ERROR_UNSPECIFIED'),
    ]
    tail = tail if tail is not None else [line('37:51.222', 'onInternetValidationStatusChanged INVALID')]
    def entry(lines):
        return (lines, hashlib.sha256(b''.join(lines)).hexdigest())
    return {'OCT03_N1H': entry([line('01:00.000','nothing')]),
            'OCT07_STOCK': entry([line('01:00.000','DATA_DEACT_CALL_IND')]),
            'OCT09_N1F_FAILURE': entry(failure),
            'OCT09_POST_CYCLE': entry(failure+tail)}

class H1B6Tests(unittest.TestCase):
    def test_overlap_and_order(self):
        r=n.normalize(bundle())
        self.assertEqual(r['oct09_overlap']['shared_prefix_lines'],6)
        self.assertEqual(r['oct09_overlap']['continuation_lines'],1)
        self.assertEqual(r['oct09_callback_vendor_order'],'CALLBACK_PRECEDES_VENDOR_INDICATION')
        self.assertEqual(len(r['sources']['OCT09_POST_CYCLE_CONTINUATION']['events']),1)
        self.assertEqual(r['root_cause'],'UNKNOWN')
    def test_prefix_conflict_rejected(self):
        x=bundle(); x['OCT09_POST_CYCLE']=([line('28:00.577','tampered')]+x['OCT09_POST_CYCLE'][0][1:], 'x')
        with self.assertRaisesRegex(n.IntegrityError,'PREFIX_MISMATCH'):n.normalize(x)
    def test_no_attribution_cid101(self):
        e=n.normalize(bundle())['sources']['OCT09_N1F_FAILURE']['events'][-1]
        self.assertEqual(e['fields']['cid'],101)
        self.assertEqual(e['fields']['active'],0)
        self.assertEqual(e['internet_bearer_attribution'],'NOT_ESTABLISHED')
    def test_vendor_codes_remain_opaque(self):
        e=n.normalize(bundle())['sources']['OCT09_N1F_FAILURE']['events']
        self.assertEqual(next(x for x in e if 'VENDOR_DEACT_CALLBACK' in x['kinds'])['fields']['vendor_result_decimal'],1314684)
        self.assertEqual(next(x for x in e if 'VENDOR_NETWORK_CAUSE' in x['kinds'])['fields']['vendor_cause_hex'],'0x140F7C')
        self.assertEqual(1314684,int('140F7C',16))
    def test_invalid_word_alone_not_callback(self):
        x=n.extract([line('28:00.000','INVALID unrelated')],'TEST','test')
        self.assertEqual(x['events'],[])
    def test_dsrm_selection_not_execution(self):
        r=n.normalize(bundle())
        self.assertEqual(r['dsrm_execution'],'NOT_ESTABLISHED')
    def test_time_regression_kept(self):
        x=n.extract([line('28:00.002','INFO'),line('28:00.001','DATA_DEACT_CALL_IND')],'TEST','test')
        self.assertEqual(x['timestamp_regression_lines'],[2])
        self.assertEqual(x['events'][0]['line'],2)
    def test_year_invalid_rejected(self):
        with self.assertRaisesRegex(n.IntegrityError,'INVALID_TIMESTAMP'):
            n.extract([b'02-29 01:00:00.000 TAG: DATA_DEACT_CALL_IND\n'],'T','s')
    def test_no_timestamp_not_silent(self):
        x=n.extract([b'header\n',line('28:00.000','DATA_DEACT_CALL_IND')],'T','s')
        self.assertEqual(x['unparsed_timestamp_lines'],1)
    def test_postcycle_not_recovered(self):
        self.assertEqual(n.normalize(bundle())['post_cycle_validated_recovery'],'NOT_PROVEN')

if __name__=='__main__': unittest.main()
