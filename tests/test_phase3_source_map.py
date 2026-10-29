"""Synthetic mapping contract tests; source quotations never enter tracked tests."""
import copy
import hashlib
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'scripts'))
from phase3_source_map import build_mapping, rules_from_mapping
import test_vertex_probe as fixtures


class MappingTests(unittest.TestCase):
    def setUp(self):
        fixture = fixtures.VertexProbeTests(); fixture.setUp()
        self.body = b'%PDF-SYNTHETIC-NOT-A-REAL-DOCUMENT'
        self.source = dict(source_id='SYN-MAPPING', sha256=hashlib.sha256(self.body).hexdigest(), page_count=2)
        self.run = dict(source_id='SYN-MAPPING', source_sha256=self.source['sha256'],
                        finish_reason='STOP', output=copy.deepcopy(fixture.output))
        self.extracted = dict(source_id='SYN-MAPPING', pages=[{'pdf_page': 1, 'text': ''}, {'pdf_page': 2, 'text': ''}])

    def build(self):
        return build_mapping(self.source, self.run, self.extracted, self.body)

    def test_certificate_gap_and_review_not_silently_filled(self):
        bundle = self.build()
        self.assertIn('supporting_certificate', bundle['missing_roles'])
        self.assertFalse(bundle['relationships_reviewed'])
        self.assertFalse(bundle['accepted_for_business_use'])
        self.assertTrue(all(c['review_status']=='pending_human_source_review' for c in bundle['clauses']))

    def test_wrong_pdf_and_run_hash_are_rejected(self):
        self.body += b'CHANGED'
        with self.assertRaises(ValueError): self.build()
        self.body = b'%PDF-SYNTHETIC-NOT-A-REAL-DOCUMENT'
        self.run['source_sha256'] = 'changed'
        with self.assertRaises(ValueError): self.build()

    def test_incomplete_page_ledger_rejected(self):
        self.extracted['pages'].pop()
        with self.assertRaises(ValueError): self.build()

    def test_missing_clause_does_not_get_replaced_with_other_field(self):
        self.run['output']['local_sme_initial_security_exempt'] = None
        self.run['output']['citations'] = [c for c in self.run['output']['citations'] if c['field']!='local_sme_initial_security_exempt']
        self.assertIn('sme_exception', self.build()['missing_roles'])

    def reviewed_bundle(self):
        bundle = self.build()
        for c in bundle['clauses']:
            c.update(review_status='reviewed', review_note='Synthetic source checked')
        bundle['clauses'].append(dict(id='SYN-CERT', role='supporting_certificate',
            source_version=bundle['source_sha256'], pdf_page=2, quote='Synthetic certificate clause',
            review_status='reviewed', review_note='Synthetic condition checked'))
        bundle.update(missing_roles=[], relationships_reviewed=True,
                      reviewed_conditions=bundle['proposed_conditions'])
        return bundle

    def test_real_candidates_cannot_automatically_become_rules(self):
        with self.assertRaises(ValueError): rules_from_mapping(self.build())

    def test_reviewed_compound_mapping_builds_scoped_rules(self):
        security, certificate = rules_from_mapping(self.reviewed_bundle())
        self.assertEqual(('LOCAL_ESTABLISHMENT', 'SME_CLASSIFICATION', 'SME_CERTIFICATE'), security.except_if)
        self.assertEqual(('CLAIMS_SECURITY_EXEMPTION',), certificate.applies_if)

    def test_edited_source_or_unreviewed_condition_rejected(self):
        for key, value in [('reviewed_conditions', {}), ('relationships_reviewed', False)]:
            bundle = self.reviewed_bundle(); bundle[key] = value
            with self.assertRaises(ValueError): rules_from_mapping(bundle)
        bundle = self.reviewed_bundle(); bundle['clauses'][0]['source_version'] = 'changed'
        with self.assertRaises(ValueError): rules_from_mapping(bundle)
