"""Explicit import of provisional Software clauses; no verification or Tasks.

Requires deployed source-workspace code in dev-agentforce. No retries/fallbacks.
Anonymous Apex containing source text and CLI results remain ignored locally.
"""
import argparse
import base64
import json
import shutil
import subprocess
from prepare_software_workspace import ROOT, prepare_workspace


def execute_import(root=ROOT):
    directory=root/'local-artifacts/phase3'
    path=directory/'software-workspace.json'
    saved=json.loads(path.read_text(encoding='utf-8'))
    prepare_workspace(root,saved['asOf'])
    if saved!=json.loads(path.read_text(encoding='utf-8')):
        raise ValueError('Prepared payload changed; review regenerated clauses before importing')
    executable=shutil.which('sf.cmd') or shutil.which('sf')
    if not executable:
        raise ValueError('Salesforce CLI unavailable; no fallback')
    encoded=base64.b64encode(json.dumps(saved,ensure_ascii=False).encode('utf-8')).decode('ascii')
    script=directory/'import-software.apex'
    script.write_text("String payload=EncodingUtil.base64Decode('"+encoded+"').toString();\n"
        "Id workspace=EtimadAssessmentService.importSoftwareWorkspace(payload);\n"
        "System.debug('ETIMAD_SOURCE_WORKSPACE_IMPORTED');\n",encoding='utf-8')
    result=subprocess.run([executable,'apex','run','--file',str(script),'--target-org','dev-agentforce','--json'],
        capture_output=True,text=True,encoding='utf-8',timeout=120,shell=False)
    (directory/'import-software-result.json').write_text(result.stdout,encoding='utf-8')
    if result.returncode:
        raise ValueError('Org error: stop; inspect ignored result; no retry')
    report=json.loads(result.stdout)
    if report.get('status')!=0 or report.get('result',{}).get('success') is not True:
        raise ValueError('Import outcome not confirmed; stop')
    return dict(status='imported_provisional',target_org='dev-agentforce',
        supplier_evidence='empty_synthetic_profile',source_verified=False,tasks_created=0)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute',action='store_true')
    args=parser.parse_args()
    if not args.execute:
        parser.error('--execute is required to store selected quotations in Salesforce')
    try:
        print(json.dumps(execute_import()))
    except (ValueError,KeyError,OSError,TypeError,subprocess.TimeoutExpired):
        print(json.dumps({'status':'stopped','reason':'Import unconfirmed; inspect local artifacts, no retry or fallback.'}))
        raise SystemExit(1)
