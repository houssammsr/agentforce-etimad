"""Summarize real, independently quality-reviewed paired timing trials only."""
import argparse
import csv
import json
import statistics
import hashlib
from collections import defaultdict
from pathlib import Path


def summarize(rows):
    rows = list(rows)
    pairs = defaultdict(dict)
    excluded = 0
    for row in rows:
        if row['mode'] not in {'manual', 'assisted'}:
            raise ValueError('Mode must be manual or assisted')
        if row['completed'].lower() != 'true' or not row['quality_reviewed_by']:
            excluded += 1
            continue
        if row['quality_reviewed_by'] == row['participant_id']:
            raise ValueError('Quality review must be independent of the timed participant')
        key = (row['pair_id'], row['participant_id'], row['document_id'])
        if row['mode'] in pairs[key]:
            raise ValueError('Duplicate mode in a matched pair')
        seconds = float(row['active_seconds'])
        if not 0 < seconds < float('inf'):
            raise ValueError('Active time must be finite and positive')
        ids = json.loads(row.get('reviewed_assertion_ids', '[]'))
        if (not isinstance(ids, list) or not ids or any(type(i) is not str or not i for i in ids)
                or len(set(ids)) != len(ids) or not row.get('annotation_version')):
            raise ValueError('Exact assertion IDs and annotation version are required')
        scope = hashlib.sha256(json.dumps([row['annotation_version'], sorted(ids)],
                                         ensure_ascii=False).encode('utf-8')).hexdigest()
        parsed = dict(row, active_seconds=seconds, scope_hash=scope)
        for field in ('reviewed_assertions', 'missed_critical', 'false_mandatory', 'citation_errors'):
            parsed[field] = int(row[field])
            if parsed[field] < 0:
                raise ValueError('Quality counts cannot be negative')
        if not parsed['reviewed_assertions']:
            raise ValueError('Review scope cannot be empty')
        if parsed['reviewed_assertions'] != len(ids):
            raise ValueError('Assertion count must match the explicit scope')
        pairs[key][row['mode']] = parsed
    completed = [p for p in pairs.values() if set(p) == {'manual', 'assisted'}]
    for pair in completed:
        if pair['manual']['scope_hash'] != pair['assisted']['scope_hash']:
            raise ValueError('Paired trials must use the same review scope')
    savings = [(p['manual']['active_seconds'] - p['assisted']['active_seconds']) /
               p['manual']['active_seconds'] * 100 for p in completed]
    return {'status': 'measured' if savings else 'not_measured', 'completed_pairs': len(savings),
            'input_trials': len(rows), 'excluded_incomplete_or_unreviewed': excluded,
            'unpaired_eligible_trials': sum(len(p) for p in pairs.values() if len(p) != 2),
            'median_time_reduction_percent': statistics.median(savings) if savings else None,
            'range_percent': [min(savings), max(savings)] if savings else None,
            'quality_totals': {mode: {f: sum(p[mode][f] for p in completed)
                              for f in ('missed_critical', 'false_mandatory', 'citation_errors')}
                              for mode in ('manual', 'assisted')} if completed else None,
            'limitation': 'Small paired samples and repeated-document learning effects do not establish population ROI.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trials', type=Path, default=Path(__file__).resolve().parents[1] / 'data/baseline/trials.csv')
    args = parser.parse_args()
    with args.trials.open(encoding='utf-8-sig', newline='') as stream:
        print(json.dumps(summarize(list(csv.DictReader(stream))), indent=2))
