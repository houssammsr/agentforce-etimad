"""Import the three user-provided government PDFs without network or LLM calls."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUTS = [
    ('TAQEEM-SOFTWARE-2026', 'bid_attachment.pdf', '157', 'PRCOMP20260200015', '2026-03-12', 61),
    ('TAQEEM-ERP-2026', 'bid_attachment (1).pdf', '151', 'PRCOMP20260100010', '2026-02-15', 36),
    ('TAQEEM-AUDIT-2026', 'bid_attachment (2).pdf', '152', 'PRCOMP20260100009', '2026-02-24', 37),
]


def main():
    from pypdf import PdfReader
    records = []
    for source_id, filename, endpoint, reference, issued, expected_pages in INPUTS:
        source = ROOT / filename
        if not source.is_file():
            raise FileNotFoundError(f'Missing user-provided input: {filename}')
        body = source.read_bytes()
        if not body.startswith(b'%PDF-'):
            raise ValueError(f'Not a PDF: {filename}')
        reader = PdfReader(source)
        if len(reader.pages) != expected_pages:
            raise ValueError(f'Unexpected page count for {source_id}; verify document identity')
        raw = ROOT / 'data/raw' / f'{source_id}.pdf'
        raw.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, raw)
        pages = [{'pdf_page': i + 1, 'text': page.extract_text() or ''}
                 for i, page in enumerate(reader.pages)]
        extracted = ROOT / 'data/extracted' / f'{source_id}.json'
        extracted.parent.mkdir(parents=True, exist_ok=True)
        extracted.write_text(json.dumps({'source_id': source_id, 'pages': pages},
                                       ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        records.append({
            'source_id': source_id, 'reference': reference,
            'source_url': f'https://taqeem.gov.sa/web/content/portal.tender/{endpoint}/bid_attachment?download=true',
            'acquisition': 'user_provided_browser_download', 'received_on': '2026-10-28',
            'issued_on': issued, 'buyer': 'Saudi Authority for Accredited Valuers (Taqeem)',
            'buyer_type': 'government_authority', 'language': 'ar',
            'cohort': 'primary_government_booklet', 'split': 'development',
            'template_group': 'taqeem_2026_shared_template',
            'redistribution': 'not_granted_original_and_extracted_text_local_only',
            'cloud_upload_authorized': False,
            'classification_marking': 'Internal' if endpoint == '151' else 'not_assessed_as_public_license',
            'page_count': len(pages), 'bytes': len(body),
            'sha256': hashlib.sha256(body).hexdigest(),
            'local_path': raw.relative_to(ROOT).as_posix(),
            'extracted_path': extracted.relative_to(ROOT).as_posix(),
            'review_status': 'agent_review_candidate_requires_independent_review',
        })
        print(source_id, len(pages), 'pages imported locally')
    manifest = {'schema_version': 1, 'sources': records,
                'limitation': 'Three booklets from one buyer/template family; not an independent held-out benchmark.'}
    (ROOT / 'data/sources/government_manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
