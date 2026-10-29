"""Prepare provisional Software clauses for explicit source-bound Salesforce import.

Offline only. Does not attest to source evidence or upload anything. All generated
quotations/payloads remain in ignored local-artifacts. Existing grant is checked.
"""
import argparse
import hashlib
import json
from datetime import date
from pathlib import Path
from phase3_source_map import ROOT, prepare


def prepare_workspace(root: Path, as_of: str):
    if date.fromisoformat(as_of).isoformat() != as_of:
        raise ValueError('Explicit ISO assessment date required')
    source_id = 'TAQEEM-SOFTWARE-2026'
    prepare(root, source_id)
    mapping_path = root/'local-artifacts/phase3'/f'{source_id}-mapping.json'
    bundle = json.loads(mapping_path.read_text(encoding='utf-8'))
    source = next(s for s in json.loads((root/'data/sources/government_manifest.json').read_text(encoding='utf-8'))['sources'] if s['source_id']==source_id)
    grant = json.loads((root/'data/sources/phase2_authorization.json').read_text(encoding='utf-8'))
    if grant.get('authority') != 'explicit_user_message' or not any(
        d.get('provider')=='Salesforce' and d.get('target_org_alias')=='dev-agentforce'
        and d.get('scope')=='Selected source-derived requirements and quotations'
        for d in grant.get('destinations', [])):
        raise ValueError('No selected-source Salesforce storage grant')
    pages = json.loads((root/source['extracted_path']).read_text(encoding='utf-8'))['pages']
    text = pages[13]['text']
    # Booklet-specific section anchors: ambiguous or changed extraction fails closed.
    start = text.index('35 ')
    end = text.index('36 ', start)
    section = text[start:end]
    marker = section.index('د.')
    quote = section[marker:].strip()
    if not 30 <= len(quote) <= 1000 or 'منشآت' not in quote or 'عدم تقديم' not in quote:
        raise ValueError('Certificate clause needs manual location; no fallback')
    bundle['clauses'].append(dict(id=source_id+':supporting_certificate:0', role='supporting_certificate',
        source_version=source['sha256'], pdf_page=14, quote=quote, native_text_match=True,
        review_status='pending_human_source_review', clause_label='35(d)'))
    bundle['missing_roles'] = [r for r in bundle['missing_roles'] if r!='supporting_certificate']
    roles = {'base_security':'BID_SECURITY', 'sme_exception':'SME_EXCEPTION',
             'supporting_certificate':'SME_CERTIFICATE'}
    if len(bundle['clauses'])!=3 or {c['role'] for c in bundle['clauses']} != set(roles):
        raise ValueError('Exactly three unambiguous clauses required')
    candidates = []
    for c in bundle['clauses']:
        candidates.append(dict(importKey=hashlib.sha256((source['sha256']+':'+c['role']).encode()).hexdigest(),
            sourceId=source_id, sourceHash=source['sha256'], documentVersion=source['sha256'],
            sourceUrl=source['source_url'], pageCount=source['page_count'], pdfPage=c['pdf_page'],
            concept=roles[c['role']], fact=c['quote'], quote=c['quote'], synthetic=False))
    payload = dict(supplier='SYNTHETIC-SOFTWARE-SUPPLIER', asOf=as_of, candidates=candidates)
    mapping_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding='utf-8')
    out = root/'local-artifacts/phase3/software-workspace.json'
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    return dict(status='prepared_unverified', clauses=3, certificate_pdf_page=14,
                model_calls=0, salesforce_writes=0, accepted_for_business_use=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--as-of', required=True)
    args=parser.parse_args()
    try:
        print(json.dumps(prepare_workspace(ROOT,args.as_of)))
    except (ValueError, KeyError, OSError, TypeError):
        print(json.dumps({'status':'stopped','reason':'Source, grant or clause invalid; no fallback.'}))
        raise SystemExit(1)
