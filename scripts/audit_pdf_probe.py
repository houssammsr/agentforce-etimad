"""Offline audit of already-saved PDF probes; makes no model requests."""
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def surface(text):
    return re.sub(r'\s+', '', unicodedata.normalize('NFKC', text))


def audit():
    manifest = json.loads((ROOT / 'data/sources/government_manifest.json').read_text(encoding='utf-8'))
    rows = []
    for source in manifest['sources']:
        run = json.loads((ROOT / 'local-artifacts/vertex-pdf' / (source['source_id'] + '.json')).read_text(encoding='utf-8'))
        extracted = json.loads((ROOT / source['extracted_path']).read_text(encoding='utf-8'))
        comparisons = run['validation']['candidate_comparisons']
        citations = run['output']['citations']
        matches = sum(surface(c['quote']) in surface(extracted['pages'][c['pdf_page'] - 1]['text']) for c in citations)
        rows.append({'source_id': source['source_id'], 'pages': source['page_count'],
            'http_status': 200, 'finish_reason': run['finish_reason'],
            'elapsed_seconds': run['elapsed_seconds'], 'requested_model': run['model_requested'],
            'returned_model': run['model_returned'],
            'strict_candidate_matches': sum(c['matches_candidate'] for c in comparisons.values()),
            'candidate_checks': len(comparisons),
            'mismatches': [k for k, v in comparisons.items() if not v['matches_candidate']],
            'reference_equal_ignoring_whitespace': surface(run['output']['document_reference']) == surface(source['reference']),
            'citation_count': len(citations), 'quote_surface_matches': matches,
            'quotes_with_ellipsis': sum('...' in c['quote'] or '…' in c['quote'] for c in citations),
            'citation_semantic_accuracy': None,
            'usage': run['usage']})
    return {'scope': 'Three full PDFs; ten selected candidate field checks per document; one run each.',
            'documents': rows,
            'whole_document_recall': None, 'independent_gold': False,
            'quotation_audit_limit': 'NFKC and whitespace-insensitive matching against extracted native text. '
                'A match is not semantic proof; a mismatch may be formatting/extraction variance or reconstructed wording.',
            'raw_results': 'Ignored local-artifacts/vertex-pdf/*.json; never commit source-derived responses.'}


if __name__ == '__main__':
    report = audit()
    path = ROOT / 'local-artifacts/vertex-pdf-summary.json'
    path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))
