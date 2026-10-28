"""Check pilot annotation integrity. This does NOT measure model accuracy."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATEGORIES = {'date', 'clarification', 'eligibility', 'submission', 'evaluation', 'exception', 'contract', 'preference'}


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def validate(manifest, annotations, queries, root=None):
    errors = []
    sources = {s['source_id']: s for s in manifest['sources']}
    if len(sources) != len(manifest['sources']):
        errors.append('Duplicate source IDs')
    hashes = {}
    groups = {}
    for source in sources.values():
        if source['sha256'] in hashes:
            errors.append('Duplicate document bytes across source IDs')
        hashes[source['sha256']] = source['source_id']
        groups.setdefault(source['template_group'], set()).add(source['split'])
        if root:
            path = root / source['local_path']
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != source['sha256']:
                errors.append(f"Missing or changed source: {source['source_id']}")
            extracted = root / source['extracted_path']
            if not extracted.is_file():
                errors.append(f"Missing extracted pages: {source['source_id']}")
            else:
                pages = read(extracted)['pages']
                if [p['pdf_page'] for p in pages] != list(range(1, source['page_count'] + 1)):
                    errors.append(f"Incomplete page ledger: {source['source_id']}")
    if any(len(splits) != 1 for splits in groups.values()):
        errors.append('Template family spans dataset splits: leakage risk')
    ids = {}
    for item in annotations['requirements']:
        if item['id'] in ids:
            errors.append(f"Duplicate annotation: {item['id']}")
        ids[item['id']] = item
        source = sources.get(item['document_id'])
        if not source:
            errors.append(f"Unknown document: {item['id']}")
            continue
        if item['category'] not in CATEGORIES:
            errors.append(f"Unknown category: {item['id']}")
        page = item['citation']['pdf_page']
        if type(page) is not int or not 1 <= page <= source['page_count']:
            errors.append(f"Invalid citation page: {item['id']}")
        if item['review_status'] != 'agent_candidate_not_independent_gold':
            errors.append(f"Untracked review-state change: {item['id']}")
        if item['concept'] == 'TECHNICAL_PASS':
            value = item['expected']
            if value['unit'] != 'points' or not 0 <= value['minimum'] <= value['technical_maximum']:
                errors.append(f"Invalid score units: {item['id']}")
        if item['category'] == 'date' and item['expected']['timezone'] is not None:
            errors.append(f"Unreviewed timezone assumption: {item['id']}")
    query_ids = set()
    for query in queries['queries']:
        if query['id'] in query_ids:
            errors.append('Duplicate query ID')
        query_ids.add(query['id'])
        for expected in query['expected_requirement_ids']:
            if expected not in ids or ids[expected]['document_id'] != query['document_id']:
                errors.append(f"Cross-document/unknown query target: {query['id']}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-local', action='store_true', help='Also verify ignored PDF hashes and page ledgers')
    args = parser.parse_args()
    manifest = read(ROOT / 'data/sources/government_manifest.json')
    annotations = read(ROOT / 'data/annotations/requirements.json')
    queries = read(ROOT / 'data/annotations/queries.json')
    errors = validate(manifest, annotations, queries, ROOT if args.check_local else None)
    result = {'status': 'failed' if errors else 'passed', 'documents': len(manifest['sources']),
              'candidate_assertions': len(annotations['requirements']), 'query_cases': len(queries['queries']),
              'independent_gold_labels': 0, 'held_out_documents': 0, 'errors': errors,
              'model_accuracy': None, 'manual_baseline_seconds': None}
    print(json.dumps(result, indent=2))
    raise SystemExit(bool(errors))


if __name__ == '__main__':
    main()
