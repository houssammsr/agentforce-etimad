"""Phase 0/1 contracts; these do not measure model behavior."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from vertex_pdf_probe import authorize, checks, validate_output
from normalize_calendar import normalize_hijri
import test_vertex_probe as vertex_tests
import test_phase1_integrity as baseline_tests


class FoundationTests(unittest.TestCase):
    def test_authorization_rejects_changed_document_and_destination(self):
        grant = json.loads((ROOT / 'data/sources/cloud_authorizations.json').read_text())
        source = json.loads((ROOT / 'data/sources/government_manifest.json').read_text())['sources'][0]
        config = {'GOOGLE_CLOUD_PROJECT': 'datagoro', 'GOOGLE_CLOUD_LOCATION': 'global'}
        authorize(source, config, grant)
        for key, value in [('source_id', 'NEW'), ('sha256', 'changed')]:
            with self.assertRaises(ValueError):
                authorize(dict(source, **{key: value}), config, grant)
        for key in config:
            with self.assertRaises(ValueError):
                authorize(source, dict(config, **{key: 'other'}), grant)

    def test_each_populated_fact_requires_evidence(self):
        fixture = vertex_tests.VertexProbeTests(); fixture.setUp()
        self.assertTrue(validate_output(fixture.output, 'STOP', 2))
        fixture.output['citations'].pop()
        self.assertFalse(validate_output(fixture.output, 'STOP', 2))

    def test_out_of_bounds_page_rejected(self):
        fixture = vertex_tests.VertexProbeTests(); fixture.setUp()
        fixture.output['citations'][0]['pdf_page'] = 3
        self.assertFalse(validate_output(fixture.output, 'STOP', 2))

    def test_expected_values_are_document_specific(self):
        labels = json.loads((ROOT / 'data/annotations/requirements.json').read_text())
        source = json.loads((ROOT / 'data/sources/government_manifest.json').read_text())['sources'][0]
        fixture = vertex_tests.VertexProbeTests(); fixture.setUp()
        for r in labels['requirements']:
            if r['document_id'] == source['source_id']:
                if r['concept'] == 'LOCAL_SME_SECURITY_EXEMPTION':
                    r['expected']['local_SME_exempt_from_initial_security'] = False
                if r['concept'] == 'CERTIFICATE_REMEDY':
                    r['expected']['maximum_working_days'] = 7
        result = checks({'output': fixture.output}, labels, source)['candidate_comparisons']
        self.assertFalse(result['local_sme_initial_security_exempt']['expected_candidate'])
        self.assertEqual(7, result['certificate_remedy_max_working_days']['expected_candidate'])

    def test_same_count_different_scope_or_version_rejected(self):
        from summarize_baseline import summarize
        fixture = baseline_tests.BaselineTests()
        a = fixture.trial('manual', 100)
        for field, value in [('annotation_version', 'other'),
                             ('reviewed_assertion_ids', json.dumps([str(i) for i in range(1, 21)]))]:
            b = fixture.trial('assisted', 75); b[field] = value
            with self.assertRaises(ValueError):
                summarize([a, b])

    def test_calendar_independent_runtime_pairs(self):
        refs = json.loads((ROOT / 'data/fixtures/calendar_reference_pairs.json').read_text(encoding='utf-8-sig'))
        for pair in refs['pairs']:
            with self.subTest(pair=pair):
                self.assertEqual(pair['gregorian'], normalize_hijri(pair['hijri'])['gregorian_iso'])
        self.assertEqual('2023-12-28', normalize_hijri('١٤٤٥/٠٦/١٥ هـ')['gregorian_iso'])

    def test_invalid_and_ambiguous_dates_rejected(self):
        for value in ['1448/13/01', '1448/01/31', '1439/01/01', '1501/01/01',
                      '05/06/1448', '1448/05/14 tomorrow', None]:
            with self.subTest(value=value), self.assertRaises((ValueError, OverflowError)):
                normalize_hijri(value)
