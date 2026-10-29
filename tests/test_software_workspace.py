"""Offline preparation/import tests using only invented source content."""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from prepare_software_workspace import prepare_workspace
from import_software_workspace import execute_import


class SoftwareWorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory();self.addCleanup(self.directory.cleanup)
        self.root=Path(self.directory.name)
        (self.root/'data/sources').mkdir(parents=True)
        (self.root/'local-artifacts/phase3').mkdir(parents=True)
        source=dict(source_id='TAQEEM-SOFTWARE-2026',sha256='a'*64,page_count=61,
                    extracted_path='native.json',source_url='https://example.invalid/synthetic')
        (self.root/'data/sources/government_manifest.json').write_text(json.dumps({'sources':[source]}))
        self.grant=dict(authority='explicit_user_message',destinations=[dict(provider='Salesforce',
            target_org_alias='dev-agentforce',scope='Selected source-derived requirements and quotations')])
        self.save_grant()
        pages=[dict(pdf_page=i+1,text='') for i in range(61)]
        pages[13]['text']='35 Synthetic section\nد. شهادة منشآت في حال عدم تقديم ضمان تجريبي.\n36 Synthetic next section'
        (self.root/'native.json').write_text(json.dumps({'pages':pages}),encoding='utf-8')
        clauses=[dict(role=role,quote='Synthetic quote',pdf_page=page)
                 for role,page in [('base_security',15),('sme_exception',16)]]
        self.bundle=dict(clauses=clauses,missing_roles=['supporting_certificate'])

    def save_grant(self):
        (self.root/'data/sources/phase2_authorization.json').write_text(json.dumps(self.grant))

    def prepare(self):
        def candidate_mapping(root,source_id):
            (root/'local-artifacts/phase3'/f'{source_id}-mapping.json').write_text(json.dumps(self.bundle))
        with patch('prepare_software_workspace.prepare',side_effect=candidate_mapping):
            return prepare_workspace(self.root,'2026-03-01')

    def test_exact_certificate_and_provisional_source_payload(self):
        result=self.prepare()
        self.assertFalse(result['accepted_for_business_use'])
        payload=json.loads((self.root/'local-artifacts/phase3/software-workspace.json').read_text(encoding='utf-8'))
        self.assertEqual(3,len(payload['candidates']))
        certificate=next(c for c in payload['candidates'] if c['concept']=='SME_CERTIFICATE')
        self.assertEqual(14,certificate['pdfPage'])
        self.assertFalse(certificate['synthetic'])
        self.assertNotIn('verified',certificate)
        self.assertTrue(payload['supplier'].startswith('SYNTHETIC-'))

    def test_missing_grant_stops(self):
        self.grant['destinations']=[];self.save_grant()
        with self.assertRaises(ValueError):self.prepare()

    def test_ambiguous_clause_roles_stop(self):
        self.bundle['clauses'].append(self.bundle['clauses'][0])
        with self.assertRaises(ValueError):self.prepare()

    def test_changed_payload_rejected_before_cli(self):
        self.prepare()
        with patch('import_software_workspace.prepare_workspace'),patch('import_software_workspace.shutil.which',return_value='sf'),patch('import_software_workspace.subprocess.run') as run:
            # Re-preparation would normally restore the source-bound value.
            def regenerate(root,as_of):
                p=root/'local-artifacts/phase3/software-workspace.json'
                data=json.loads(p.read_text(encoding='utf-8'));data['candidates'][0]['quote']='different'
                p.write_text(json.dumps(data),encoding='utf-8')
            with patch('import_software_workspace.prepare_workspace',side_effect=regenerate):
                with self.assertRaises(ValueError):execute_import(self.root)
            run.assert_not_called()

    def test_org_failure_is_not_retried(self):
        self.prepare()
        with patch('import_software_workspace.prepare_workspace'),patch('import_software_workspace.shutil.which',return_value='sf'),patch('import_software_workspace.subprocess.run') as run:
            run.return_value.returncode=1;run.return_value.stdout='{}'
            with self.assertRaises(ValueError):execute_import(self.root)
            self.assertEqual(1,run.call_count)
            args=run.call_args.args[0]
            self.assertEqual('dev-agentforce',args[args.index('--target-org')+1])
