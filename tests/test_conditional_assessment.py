"""Synthetic rules/evidence only; no claim of actual supplier eligibility."""
import sys
import unittest
from dataclasses import replace
from datetime import date
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'scripts'))
from assess_requirements import Evidence
from conditional_assessment import Clause, Rule, evaluate


class ConditionalTests(unittest.TestCase):
    def setUp(self):
        self.clauses = tuple(Clause(c, 'v1', i+1, True) for i, c in enumerate(('base', 'exception', 'certificate')))
        self.rule = Rule('security', 'BID_SECURITY', 'v1', self.clauses,
                         except_if=('LOCAL_SME_STATUS', 'SME_CERTIFICATE'))

    def evidence(self, concept, assertion=True, **kw):
        args = dict(id=concept, supplier_id='SYN-A', concept=concept, verified=True,
                    valid_from=date(2026, 1, 1), valid_to=date(2026, 12, 31), assertion=assertion)
        return Evidence(**(args | kw))

    def check(self, evidence, rule=None):
        return evaluate(rule or self.rule, evidence, supplier_id='SYN-A',
                        as_of=date(2026, 6, 1), expected_version='v1')

    def test_all_conditions_required_and_final_security_not_exempt(self):
        evidence = [self.evidence(c) for c in self.rule.except_if]
        self.assertEqual('not_applicable', self.check(evidence)['status'])
        final = Rule('final', 'FINAL_SECURITY', 'v1', (self.clauses[0],))
        self.assertEqual('unknown', self.check(evidence, final)['status'])

    def test_missing_condition_cannot_be_inferred_from_certificate(self):
        evidence = [self.evidence('SME_CERTIFICATE'), self.evidence('BID_SECURITY', False)]
        self.assertEqual('EXCEPTION_APPLICABILITY_UNRESOLVED', self.check(evidence)['reason'])

    def test_expired_unverified_or_wrong_supplier_cannot_exempt(self):
        for changes in ({'valid_to': date(2026, 5, 31)}, {'verified': False}, {'supplier_id': 'SYN-B'}):
            evidence = [self.evidence('LOCAL_SME_STATUS'), self.evidence('SME_CERTIFICATE', **changes)]
            self.assertEqual('unknown', self.check(evidence)['status'])

    def test_negative_condition_resolves_exception_and_allows_proven_gap(self):
        evidence = [self.evidence('LOCAL_SME_STATUS', False), self.evidence('BID_SECURITY', False)]
        self.assertEqual('gap', self.check(evidence)['status'])

    def test_conflicting_condition_blocks_exemption(self):
        evidence = [self.evidence(c) for c in self.rule.except_if]
        evidence.append(self.evidence('LOCAL_SME_STATUS', False, id='NEGATIVE'))
        self.assertEqual('conflicting', self.check(evidence)['status'])

    def test_conditional_certificate_obligation(self):
        rule = Rule('certificate', 'SME_CERTIFICATE', 'v1', self.clauses,
                    applies_if=('CLAIMS_SECURITY_EXEMPTION',))
        self.assertEqual('unknown', self.check([], rule)['status'])
        self.assertEqual('not_applicable', self.check([self.evidence('CLAIMS_SECURITY_EXEMPTION', False)], rule)['status'])
        evidence = [self.evidence('CLAIMS_SECURITY_EXEMPTION'), self.evidence('SME_CERTIFICATE')]
        self.assertEqual('supported', self.check(evidence, rule)['status'])

    def test_unreviewed_or_mixed_versions_never_pass(self):
        evidence = [self.evidence(c) for c in self.rule.except_if]
        for clause in (replace(self.clauses[0], reviewed=False), replace(self.clauses[0], source_version='v2')):
            rule = replace(self.rule, clauses=(clause,)+self.clauses[1:])
            self.assertEqual('unknown', self.check(evidence, rule)['status'])

    def test_supported_direct_evidence_does_not_require_exception(self):
        result = self.check([self.evidence('BID_SECURITY')])
        self.assertEqual('supported', result['status'])
        self.assertEqual(['BID_SECURITY'], result['evidence_ids'])
        self.assertEqual(['base', 'exception', 'certificate'], result['clause_ids'])

    def test_invalid_evidence_and_duplicate_clauses_rejected(self):
        with self.assertRaises(ValueError):
            self.check([self.evidence('SME_CERTIFICATE', verified='yes')])
        with self.assertRaises(ValueError):
            self.check([], replace(self.rule, clauses=(self.clauses[0], self.clauses[0])))
