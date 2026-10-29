"""Synthetic domain tests; no real supplier eligibility or model accuracy claims."""
import sys
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from assess_requirements import Requirement, Evidence, assess_all


class AssessmentTests(unittest.TestCase):
    def setUp(self):
        self.requirements = [
            Requirement('security', 'v1', 'BID_SECURITY', 1, True, 'LOCAL_SME_CERT'),
            Requirement('certificate', 'v1', 'LOCAL_SME_CERT', 2, True),
            Requirement('final', 'v1', 'FINAL_SECURITY', 3, True)]

    def evidence(self, **changes):
        fields = dict(id='E1', supplier_id='SYN-A', concept='LOCAL_SME_CERT',
                      verified=True, valid_from=date(2026, 1, 1),
                      valid_to=date(2026, 12, 31), assertion=True)
        return Evidence(**(fields | changes))

    def run_case(self, evidence, **changes):
        args = dict(supplier_id='SYN-A', as_of=date(2026, 6, 1), expected_version='v1')
        return assess_all(self.requirements, evidence, **(args | changes))

    def test_exception_is_scoped_and_certificate_is_separately_assessed(self):
        rows = self.run_case([self.evidence()])
        self.assertEqual(['not_applicable', 'supported', 'unknown'], [r.status for r in rows])
        self.assertEqual(('E1',), rows[0].evidence_ids)

    def test_missing_unverified_expired_future_or_other_supplier_is_unknown(self):
        for evidence in [[], [self.evidence(verified=False)],
                         [self.evidence(valid_to=date(2026, 5, 31))],
                         [self.evidence(valid_from=date(2026, 7, 1))],
                         [self.evidence(supplier_id='SYN-B')]]:
            with self.subTest(evidence=evidence):
                self.assertEqual('unknown', self.run_case(evidence)[0].status)

    def test_conflicting_exception_does_not_authorize_exemption(self):
        rows = self.run_case([self.evidence(), self.evidence(id='E2', assertion=False)])
        self.assertEqual('conflicting', rows[0].status)

    def test_verified_negative_direct_evidence_is_gap(self):
        rows = self.run_case([self.evidence(concept='BID_SECURITY', assertion=False),
                              self.evidence(id='EX-NO', assertion=False)])
        self.assertEqual('gap', rows[0].status)

    def test_stale_or_unreviewed_requirement_cannot_pass(self):
        self.assertEqual('unknown', self.run_case([self.evidence()], expected_version='v2')[0].status)
        self.requirements = [Requirement('security', 'v1', 'BID_SECURITY', 1, False, 'LOCAL_SME_CERT')]
        self.assertEqual('unknown', self.run_case([self.evidence()])[0].status)

    def test_date_boundary_is_inclusive(self):
        self.assertEqual('not_applicable', self.run_case([self.evidence()], as_of=date(2026, 12, 31))[0].status)

    def test_duplicate_identity_rejected(self):
        with self.assertRaises(ValueError):
            self.run_case([self.evidence(), self.evidence()])
        self.requirements.append(self.requirements[0])
        with self.assertRaises(ValueError):
            self.run_case([])

    def test_invalid_interval_rejected(self):
        with self.assertRaises(ValueError):
            self.run_case([self.evidence(valid_from=date(2027, 1, 1))])

    def test_negative_direct_with_unresolved_exception_is_unknown(self):
        negative = self.evidence(id='DIRECT', concept='BID_SECURITY', assertion=False)
        for exception in [[], [self.evidence(verified=False)],
                          [self.evidence(valid_to=date(2026, 5, 31))],
                          [self.evidence(supplier_id='OTHER')]]:
            with self.subTest(exception=exception):
                result = self.run_case([negative, *exception])[0]
                self.assertEqual('unknown', result.status)
                self.assertEqual('EXCEPTION_APPLICABILITY_UNRESOLVED', result.reason)

    def test_direct_evidence_without_exception_and_positive_direct_are_supported(self):
        self.assertEqual('gap', self.run_case([self.evidence(concept='FINAL_SECURITY', assertion=False)])[2].status)
        self.assertEqual('supported', self.run_case([self.evidence(concept='BID_SECURITY')])[0].status)
