import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_pinyin_dict as g  # noqa: E402


class NormalizationTest(unittest.TestCase):
    def test_cedict_keys(self):
        self.assertEqual(g.cedict_key('zhong1 guo2'), 'zhongguo')
        self.assertEqual(g.cedict_key('lu:4'), 'lv')
        self.assertEqual(g.cedict_key('nu:e4'), 'nve')
        self.assertEqual(g.cedict_key('hua1 r5'), 'huar')
        self.assertEqual(g.cedict_key('Bei3 jing1'), 'beijing')

    def test_cedict_rejects_non_pinyin(self):
        self.assertIsNone(g.cedict_key('11 Qu1'))
        self.assertIsNone(g.cedict_key('san1 3'))
        self.assertIsNone(g.cedict_key('xx'))

    def test_unihan_keys(self):
        self.assertEqual(g.unihan_key('zhōng'), 'zhong')
        self.assertEqual(g.unihan_key('lǜ'), 'lv')
        self.assertEqual(g.unihan_key('nüè'), 'nve')
        self.assertEqual(g.unihan_key('ê̄'), 'e')
        self.assertEqual(g.unihan_key('ḿ'), 'm')
        self.assertEqual(g.unihan_key('ɡǎn'), 'gan')
        self.assertIsNone(g.unihan_key('a1'))

    def test_cedict_rows_use_simplified_and_skip_comments(self):
        rows = g.cedict_rows('# c\n中國 中国 [Zhong1 guo2] /China/\n11區 11区 [11 Qu1] /x/\n')
        self.assertEqual(rows, [('zhongguo', '中国', g.WEIGHT_CEDICT)])

    def test_unihan_rows_admit_only_listed_properties(self):
        text = 'U+4E2D\tkMandarin\tzhōng zhòng\nU+4E2D\tkCantonese\tzung1\nU+4E2D\tkTGHZ2013\t100.010:zhōng,zhòng\n'
        rows = g.unihan_rows(text, ['kMandarin', 'kTGHZ2013'])
        self.assertEqual(sorted(set((k, w) for k, _, w in rows)), [('zhong', 20), ('zhong', 30)])

    def test_weights_are_three_neutral_tiers_not_frequencies(self):
        self.assertEqual(sorted([g.WEIGHT_CEDICT, g.WEIGHT_UNIHAN_MANDARIN, g.WEIGHT_UNIHAN_TGHZ2013]), [10, 20, 30])


if __name__ == '__main__':
    unittest.main()
