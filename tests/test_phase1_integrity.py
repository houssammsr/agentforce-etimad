"""Regression tests protect evaluation integrity, not agent performance."""
import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from validate_dataset import read, validate
from summarize_baseline import summarize


class CorpusIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.manifest = read(ROOT / 'data/sources/government_manifest.json')
        self.labels = read(ROOT / 'data/annotations/requirements.json')
        self.queries = read(ROOT / 'data/annotations/queries.json')

    def check(self):
        return validate(self.manifest, self.labels, self.queries)

    def test_current_manifest(self):
        self.assertEqual([], self.check())

    def test_duplicate_source_bytes_rejected(self):
        self.manifest['sources'][1]['sha256'] = self.manifest['sources'][0]['sha256']
        self.assertTrue(any('Duplicate document' in e for e in self.check()))

    def test_same_template_cannot_be_blind_holdout(self):
        self.manifest['sources'][1]['split'] = 'test'
        self.assertTrue(any('leakage' in e for e in self.check()))

    def test_out_of_range_citation_rejected(self):
        self.labels['requirements'][0]['citation']['pdf_page'] = 999
        self.assertTrue(any('Invalid citation' in e for e in self.check()))

    def test_cross_tender_query_rejected(self):
        self.queries['queries'][0]['document_id'] = 'TAQEEM-ERP-2026'
        self.assertTrue(any('Cross-document' in e for e in self.check()))

    def test_no_invented_timezone(self):
        self.labels['requirements'][0]['expected']['timezone'] = 'Asia/Riyadh'
        self.assertTrue(any('timezone' in e for e in self.check()))


class BaselineTests(unittest.TestCase):
    def trial(self, mode, seconds):
        return dict(trial_id=mode, pair_id='P1', participant_id='reviewer1', document_id='D1',
                    annotation_version='synthetic-v1', reviewed_assertion_ids=__import__('json').dumps([str(i) for i in range(20)]),
                    mode=mode, order='1' if mode == 'manual' else '2', active_seconds=str(seconds),
                    reviewed_assertions='20', missed_critical='0', false_mandatory='0',
                    citation_errors='0', quality_reviewed_by='reviewer2', completed='true')

    def test_empty_is_not_zero_seconds_or_perfect_accuracy(self):
        self.assertEqual('not_measured', summarize([])['status'])
        self.assertIsNone(summarize([])['median_time_reduction_percent'])

    def test_unpaired_trial_is_not_a_savings_claim(self):
        self.assertEqual(0, summarize([self.trial('manual', 100)])['completed_pairs'])

    def test_known_paired_saving(self):
        self.assertEqual(25, summarize([self.trial('manual', 100), self.trial('assisted', 75)])['median_time_reduction_percent'])

    def test_regression_is_negative_not_hidden(self):
        self.assertEqual(-20, summarize([self.trial('manual', 100), self.trial('assisted', 120)])['median_time_reduction_percent'])

    def test_incomparable_scope_rejected(self):
        a, b = self.trial('manual', 100), self.trial('assisted', 75)
        b['reviewed_assertions'] = '5'
        with self.assertRaises(ValueError):
            summarize([a, b])

    def test_duplicate_trial_rejected(self):
        with self.assertRaises(ValueError):
            summarize([self.trial('manual', 100), self.trial('manual', 100)])

    def test_nonfinite_time_rejected(self):
        with self.assertRaises(ValueError):
            summarize([self.trial('manual', 'nan')])


if __name__ == '__main__':
    unittest.main()
