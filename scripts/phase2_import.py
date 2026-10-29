"""Import one prepared review using Etimad Apex, only after a successful deployment.

Explicit --execute is mandatory. Uses dev-agentforce only, never exports auth,
never retries on org errors, and stores raw CLI output only in ignored artifacts.
This tool does not verify evidence, approve a decision or create a Task.
"""
import argparse
import base64
import json
import shutil
import subprocess

from phase2_prepare import prepare
from vertex_smoke import ROOT


def import_prepared():
    directory = ROOT / 'local-artifacts/phase2'
    rows = json.loads((directory / 'candidates.json').read_text(encoding='utf-8'))
    if not isinstance(rows, list) or len(rows) != 1 or rows[0] != prepare(rows[0]['sourceId']):
        raise ValueError('Candidate changed or source is not authorized; prepare again')
    grant = json.loads((ROOT / 'data/sources/phase2_authorization.json').read_text(encoding='utf-8'))
    if not any(d.get('provider') == 'Salesforce' and d.get('target_org_alias') == 'dev-agentforce'
               and d.get('scope') == 'Selected source-derived requirements and quotations'
               for d in grant.get('destinations', [])):
        raise ValueError('Salesforce storage is not authorized')
    executable = shutil.which('sf.cmd') or shutil.which('sf')
    if not executable:
        raise ValueError('Salesforce CLI missing; no fallback')
    encoded = base64.b64encode(json.dumps(rows, ensure_ascii=False).encode('utf-8')).decode('ascii')
    apex = directory / 'import.apex'
    apex.write_text("String payload=EncodingUtil.base64Decode('" + encoded + "').toString();\n"
                    "List<Id> ids=EtimadReviewController.importCandidates(payload);\n"
                    "System.debug('ETIMAD_IMPORTED_COUNT='+ids.size());\n", encoding='utf-8')
    result = subprocess.run([executable, 'apex', 'run', '--file', str(apex),
                             '--target-org', 'dev-agentforce', '--json'],
                            capture_output=True, text=True, encoding='utf-8', timeout=120, shell=False)
    (directory / 'import-result.json').write_text(result.stdout, encoding='utf-8')
    if result.returncode:
        raise ValueError('Salesforce import failed. Stop and inspect ignored result; do not retry or substitute an org.')
    report = json.loads(result.stdout)
    if report.get('status') != 0 or report.get('result', {}).get('success') is not True:
        raise ValueError('Salesforce execution did not succeed. Stop; inspect ignored result.')
    return {'status': 'imported_unverified', 'count': 1, 'target_org': 'dev-agentforce',
            'tasks_created': 0, 'evidence_verified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    if not args.execute:
        parser.error('--execute is required; selected requirements/quotations will be stored in Salesforce')
    try:
        print(json.dumps(import_prepared()))
    except (ValueError, KeyError, OSError, subprocess.TimeoutExpired):
        print(json.dumps({'status': 'stopped', 'reason': 'Import not confirmed. Inspect local artifacts; no fallback or retry.'}))
        raise SystemExit(1)
