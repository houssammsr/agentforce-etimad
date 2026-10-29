"""Import transport tests never execute Salesforce or contain real tender data."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import phase2_import


class Phase2ImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'local-artifacts/phase2').mkdir(parents=True)
        (self.root / 'data/sources').mkdir(parents=True)
        self.row = {'sourceId': 'SYNTHETIC', 'fact': 'Synthetic only'}
        (self.root / 'local-artifacts/phase2/candidates.json').write_text(json.dumps([self.row]))
        self.grant = {'destinations': [{'provider': 'Salesforce', 'target_org_alias': 'dev-agentforce',
            'scope': 'Selected source-derived requirements and quotations'}]}
        self.write_grant()
        self.addCleanup(patch.stopall)
        patch.object(phase2_import, 'ROOT', self.root).start()
        patch.object(phase2_import, 'prepare', return_value=self.row).start()
        patch.object(phase2_import.shutil, 'which', return_value='sf.cmd').start()
        self.run = patch.object(phase2_import.subprocess, 'run').start()

    def write_grant(self):
        (self.root / 'data/sources/phase2_authorization.json').write_text(json.dumps(self.grant))

    def test_target_is_explicit_and_no_review_or_task_is_approved(self):
        self.run.return_value = SimpleNamespace(returncode=0,stdout=json.dumps({'status':0,'result':{'success':True}}))
        report=phase2_import.import_prepared()
        args=self.run.call_args.args[0]
        self.assertEqual('dev-agentforce',args[args.index('--target-org')+1])
        self.assertEqual(0,report['tasks_created'])
        self.assertFalse(report['evidence_verified'])
        apex=(self.root / 'local-artifacts/phase2/import.apex').read_text()
        self.assertNotIn('approveTask',apex)

    def test_denied_org_result_is_not_retried(self):
        self.run.return_value=SimpleNamespace(returncode=1,stdout='{"status":1}')
        with self.assertRaises(ValueError): phase2_import.import_prepared()
        self.run.assert_called_once()

    def test_changed_candidate_stops_before_cli(self):
        (self.root / 'local-artifacts/phase2/candidates.json').write_text(json.dumps([dict(self.row,fact='Changed')]))
        with self.assertRaises(ValueError): phase2_import.import_prepared()
        self.run.assert_not_called()

    def test_wrong_destination_stops_before_cli(self):
        self.grant['destinations'][0]['target_org_alias']='another-org'
        self.write_grant()
        with self.assertRaises(ValueError): phase2_import.import_prepared()
        self.run.assert_not_called()
