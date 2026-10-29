"""Offline Phase 2 contracts; synthetic facts only."""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from phase2_prepare import candidate_from_run
from vertex_pdf_probe import validate_output
import test_vertex_probe


class Phase2PrepareTests(unittest.TestCase):
    def setUp(self):
        fixture = test_vertex_probe.VertexProbeTests()
        fixture.setUp()
        self.output = fixture.output
        self.source = dict(source_id='SYN', sha256='a' * 64, page_count=2,
                           source_url='https://example.invalid/source')
        self.run = dict(source_id='SYN', source_sha256='a' * 64,
                        output=self.output, finish_reason='STOP')

    def test_candidate_has_stable_key_and_cannot_self_approve(self):
        a = candidate_from_run(self.source, self.run)
        self.assertEqual(a, candidate_from_run(self.source, self.run))
        self.assertFalse(any('verified' in k.lower() or 'approved' in k.lower() for k in a))
        changed = copy.deepcopy(self.run)
        changed['output']['citations'][2]['quote'] = 'Corrected source quote'
        # Change the actual security citation, regardless of fixture order.
        for c in changed['output']['citations']:
            if c['field'] == 'initial_security_percent': c['quote'] = 'Different evidence'
        self.assertNotEqual(a['importKey'], candidate_from_run(self.source, changed)['importKey'])

    def test_wrong_source_or_incomplete_run_rejected(self):
        for field, value in [('source_sha256', 'b' * 64), ('finish_reason', 'MAX_TOKENS')]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                candidate_from_run(self.source, dict(self.run, **{field: value}))

    def test_missing_fact_never_filled(self):
        self.output['initial_security_percent'] = None
        with self.assertRaises(ValueError): candidate_from_run(self.source, self.run)

    def test_calendar_conflict_is_not_silently_resolved(self):
        self.output['submission_date_iso'] = '2026-01-01'
        self.output['citations'].append(dict(field='submission_date_iso',pdf_page=2,quote='Synthetic date'))
        with self.assertRaises(ValueError):
            candidate_from_run(self.source, self.run, hijri_literal='1445/06/15')

    def test_invalid_dates_and_thresholds_rejected(self):
        for field,value in [('submission_date_iso','2026-02-30'),('submission_date_iso','20260101'),
                            ('initial_security_percent',-1),('initial_security_percent',101),
                            ('technical_pass_points',71),('certificate_remedy_max_working_days',-1)]:
            output = dict(self.output, **{field:value})
            with self.subTest(field=field,value=value): self.assertFalse(validate_output(output,'STOP',2))
