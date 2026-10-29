"""Prepare local-only source mapping from existing authorized extraction.

Never calls a model or Salesforce. Outputs contain private source quotations and
must remain in ignored local-artifacts. Does not infer certificate citations.
"""
import argparse
import hashlib
import json
from pathlib import Path
from audit_pdf_probe import surface
from vertex_pdf_probe import validate_output
from conditional_assessment import Clause, Rule

ROOT = Path(__file__).resolve().parents[1]
ROLE_FIELDS = {'base_security': 'initial_security_percent',
               'sme_exception': 'local_sme_initial_security_exempt'}


def rules_from_mapping(bundle):
    """Only explicitly reviewed, complete source mappings may define local rules.

    This local gate is not a Salesforce attestation or authority to approve.
    Conditions are proposed for this scenario and require relationship review.
    """
    if bundle.get('relationships_reviewed') is not True or bundle.get('missing_roles'):
        raise ValueError('Source relationships incomplete or unreviewed')
    by_role = {}
    for c in bundle['clauses']:
        if (c.get('review_status') != 'reviewed' or not c.get('review_note', '').strip()
                or c.get('source_version') != bundle['source_sha256']
                or not c.get('quote', '').strip()
                or type(c.get('pdf_page')) is not int
                or not 1 <= c['pdf_page'] <= bundle['page_count']):
            raise ValueError('Each clause requires reviewed, version-bound evidence')
        if c['role'] in by_role:
            raise ValueError('Resolve duplicate clause roles before evaluation')
        by_role[c['role']] = c
    required = {*ROLE_FIELDS, 'supporting_certificate'}
    if set(by_role) != required:
        raise ValueError('Base, exception and certificate clauses required')
    clauses = tuple(Clause(c['id'], c['source_version'], c['pdf_page'], True)
                    for c in by_role.values())
    # These scoped relationships must be affirmed by the local review overlay;
    # an issuer term or a certificate alone does not prove supplier eligibility.
    expected = {'exception_all_of': ['LOCAL_ESTABLISHMENT', 'SME_CLASSIFICATION', 'SME_CERTIFICATE'],
                'certificate_applies_if': ['OMITS_INITIAL_SECURITY']}
    if bundle.get('reviewed_conditions') != expected:
        raise ValueError('Explicit compound-condition review required')
    version = bundle['source_sha256']
    prefix = bundle['source_id']
    return (Rule(prefix+':security', 'BID_SECURITY', version, clauses,
                 except_if=tuple(expected['exception_all_of'])),
            Rule(prefix+':certificate', 'SME_CERTIFICATE', version, clauses,
                 applies_if=tuple(expected['certificate_applies_if'])))


def build_mapping(source, run, extracted, pdf_bytes):
    if hashlib.sha256(pdf_bytes).hexdigest() != source['sha256']:
        raise ValueError('Source PDF hash changed')
    if run.get('source_id') != source['source_id'] or run.get('source_sha256') != source['sha256']:
        raise ValueError('Saved extraction source mismatch')
    if not validate_output(run.get('output'), run.get('finish_reason'), source['page_count']):
        raise ValueError('Incomplete extraction')
    pages = extracted.get('pages', [])
    if extracted.get('source_id') != source['source_id'] or [p['pdf_page'] for p in pages] != list(range(1, source['page_count'] + 1)):
        raise ValueError('Incomplete local page ledger')
    clauses = []
    for role, field in ROLE_FIELDS.items():
        matches = [c for c in run['output']['citations'] if c['field'] == field]
        for i, citation in enumerate(matches):
            page = citation['pdf_page']
            clauses.append(dict(id=f"{source['source_id']}:{role}:{i}", role=role,
                                source_version=source['sha256'], pdf_page=page,
                                quote=citation['quote'],
                                native_text_match=surface(citation['quote']) in surface(pages[page-1]['text']),
                                review_status='pending_human_source_review'))
    missing = [role for role in ROLE_FIELDS if not any(c['role'] == role for c in clauses)]
    # Probe schema did not request this obligation separately. Never substitute a
    # remedy-period citation or assume the same page in a different booklet.
    missing.append('supporting_certificate')
    return dict(schema_version=1, source_id=source['source_id'], source_sha256=source['sha256'],
                page_count=source['page_count'], clauses=clauses, missing_roles=missing,
                proposed_conditions={'exception_all_of': ['LOCAL_ESTABLISHMENT', 'SME_CLASSIFICATION', 'SME_CERTIFICATE'],
                                     'certificate_applies_if': ['OMITS_INITIAL_SECURITY']},
                relationships_reviewed=False, accepted_for_business_use=False,
                scope='candidate source mapping; not supplier eligibility',
                notice='Exact quotation matching is not proof of semantic applicability.')


def prepare(root, source_id):
    manifest = json.loads((root/'data/sources/government_manifest.json').read_text(encoding='utf-8'))
    source = next((s for s in manifest['sources'] if s['source_id'] == source_id), None)
    if source is None:
        raise ValueError('Unknown source; no fallback')
    grant = json.loads((root/'data/sources/cloud_authorizations.json').read_text(encoding='utf-8'))
    if grant.get('source_hashes', {}).get(source_id) != source['sha256']:
        raise ValueError('Source grant mismatch')
    run = json.loads((root/'local-artifacts/vertex-pdf'/f'{source_id}.json').read_text(encoding='utf-8'))
    extracted = json.loads((root/source['extracted_path']).read_text(encoding='utf-8'))
    bundle = build_mapping(source, run, extracted, (root/source['local_path']).read_bytes())
    out = root/'local-artifacts/phase3'/f'{source_id}-mapping.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding='utf-8')
    return dict(source_id=source_id, citation_candidates=len(bundle['clauses']),
                missing_roles=bundle['missing_roles'], source_text_printed=False,
                accepted_for_business_use=False, model_calls=0, salesforce_writes=0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-id', required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(prepare(ROOT, args.source_id)))
    except (ValueError, KeyError, OSError, TypeError):
        print(json.dumps({'status': 'stopped', 'reason': 'Source, grant or saved extraction invalid; no fallback.'}))
        raise SystemExit(1)
