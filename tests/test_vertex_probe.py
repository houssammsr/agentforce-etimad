import copy
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from vertex_pdf_probe import validate_output
from vertex_smoke import run_probe


class VertexProbeTests(unittest.TestCase):
    def setUp(self):
        self.output = dict(document_reference='SYN-1', submission_date_iso=None,
            submission_time_literal=None, submission_timezone=None, technical_pass_points=45,
            technical_maximum_points=70, initial_security_percent=1.0,
            local_sme_initial_security_exempt=True, certificate_remedy_max_working_days=10,
            award_rule='best_combined_score', award_rule_needs_clarification=False,
            citations=[dict(field='technical_pass_points', pdf_page=2, quote='Synthetic evidence')], warnings=[])

    def test_complete_typed_output(self):
        self.assertTrue(validate_output(self.output, 'STOP'))

    def test_truncated_json_is_not_complete_even_if_parseable(self):
        self.assertFalse(validate_output(self.output, 'MAX_TOKENS'))

    def test_boolean_is_not_numeric_threshold(self):
        self.output['technical_pass_points'] = True
        self.assertFalse(validate_output(self.output, 'STOP'))

    def test_infinite_numeric_value_rejected(self):
        self.output['initial_security_percent'] = float('inf')
        self.assertFalse(validate_output(self.output, 'STOP'))

    def test_wrong_boolean_type_rejected(self):
        self.output['local_sme_initial_security_exempt'] = 'true'
        self.assertFalse(validate_output(self.output, 'STOP'))

    def test_missing_field_rejected(self):
        del self.output['document_reference']
        self.assertFalse(validate_output(self.output, 'STOP'))

    def test_missing_evidence_rejected(self):
        self.output['citations'] = []
        self.assertFalse(validate_output(self.output, 'STOP'))

    def test_malformed_citation_field_rejected_without_crashing(self):
        self.output['citations'][0]['field'] = []
        self.assertFalse(validate_output(self.output, 'STOP'))

    def test_http_error_does_not_echo_secret(self):
        fake = {'VERTEX_API_KEY': 'FAKE-SECRET-FOR-UNIT-TEST', 'GOOGLE_CLOUD_PROJECT': 'example',
                'GOOGLE_CLOUD_LOCATION': 'global', 'VERTEX_MODEL': 'example-model'}
        error = urllib.error.HTTPError('https://example.invalid/?key=FAKE-SECRET-FOR-UNIT-TEST',
                                       403, 'FAKE-SECRET-FOR-UNIT-TEST', {}, None)
        with patch('vertex_smoke.settings', return_value=fake), patch('urllib.request.urlopen', side_effect=error):
            report = run_probe()
        self.assertEqual(403, report['http_status'])
        self.assertNotIn(fake['VERTEX_API_KEY'], str(report))


if __name__ == '__main__':
    unittest.main()
