"""Prepare one provisional review from an existing authorized Vertex result, offline.

No network, Salesforce writes, source redistribution, or automatic evidence acceptance.
The JSON output belongs only in the ignored local-artifacts directory. This reuses
the existing real extraction; it does not claim a fresh live model run.
"""
import argparse
import hashlib
import json
from pathlib import Path

from normalize_calendar import normalize_hijri
from vertex_pdf_probe import validate_output
from vertex_smoke import ROOT


def candidate_from_run(source, run, *, hijri_literal=None):
    if (run.get('source_id') != source['source_id']
            or run.get('source_sha256') != source['sha256']):
        raise ValueError('Source identity/version mismatch')
    output = run.get('output')
    if not validate_output(output, run.get('finish_reason'), source['page_count']):
        raise ValueError('Incomplete or invalid extraction')
    rate = output['initial_security_percent']
    if rate is None:
        raise ValueError('No extracted guarantee fact; do not invent a replacement')
    citation = next((c for c in output['citations'] if c['field'] == 'initial_security_percent'), None)
    if not citation:
        raise ValueError('No source quotation for guarantee')
    calendar = normalize_hijri(hijri_literal) if hijri_literal else None
    if calendar and output['submission_date_iso'] and calendar['gregorian_iso'] != output['submission_date_iso']:
        raise ValueError('Hijri/Gregorian conflict requires source review')
    # An optional calendar value must come from separately checked source evidence;
    # CLI deliberately does not accept an arbitrary date argument for real imports.
    row = dict(sourceId=source['source_id'], sourceHash=source['sha256'],
        documentVersion=source['sha256'], sourceUrl=source['source_url'],
        pageCount=source['page_count'], pdfPage=citation['pdf_page'], concept='BID_SECURITY_RATE',
        fact=f'نسبة الضمان الابتدائي المستخرجة: {rate}٪. تُراجع الاستثناءات والشروط قبل أي استنتاج أهلية.',
        quote=citation['quote'], synthetic=False, hijri=None, gregorian=None)
    # This requirement is about security, so deadline facts are not imported without
    # their own reviewed citation. The calendar path is tested separately.
    identity = [row['sourceId'], row['sourceHash'], row['concept'], row['pdfPage'], row['fact'], row['quote']]
    row['importKey'] = hashlib.sha256(json.dumps(identity, ensure_ascii=False).encode()).hexdigest()
    return row


def prepare(source_id):
    manifest = json.loads((ROOT / 'data/sources/government_manifest.json').read_text(encoding='utf-8'))
    source = next((s for s in manifest['sources'] if s['source_id'] == source_id), None)
    if not source:
        raise ValueError('Unknown source; no substitute used')
    grant = json.loads((ROOT / 'data/sources/cloud_authorizations.json').read_text(encoding='utf-8'))
    phase2 = json.loads((ROOT / 'data/sources/phase2_authorization.json').read_text(encoding='utf-8'))
    if (phase2.get('authority') != 'explicit_user_message'
            or phase2.get('purpose_code') != 'phase2_requirement_review'
            or grant['source_hashes'].get(source_id) != source['sha256']):
        raise ValueError('No matching phase 2 source grant')
    if hashlib.sha256((ROOT / source['local_path']).read_bytes()).hexdigest() != source['sha256']:
        raise ValueError('Local source changed')
    run_path = ROOT / 'local-artifacts/vertex-pdf' / f'{source_id}.json'
    run = json.loads(run_path.read_text(encoding='utf-8'))
    return candidate_from_run(source, run)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-id', required=True)
    args = parser.parse_args()
    try:
        row = prepare(args.source_id)
        path = ROOT / 'local-artifacts/phase2/candidates.json'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps([row], ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps({'status': 'prepared_not_verified', 'count': 1,
                          'output': str(path.relative_to(ROOT)), 'salesforce_writes': 0}))
    except (ValueError, KeyError, OSError):
        print(json.dumps({'status': 'stopped', 'reason': 'Missing or invalid source, authorization, or extraction. No fallback.'}))
        raise SystemExit(1)
