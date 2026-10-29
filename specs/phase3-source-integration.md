# Phase 3 source integration — first implementation increment

Date: October 29, 2026. No deployment, model request, Salesforce write, commit or push in this increment.

## Implemented

- `scripts/phase3_source_map.py` validates original PDF hash, saved-run source identity, complete extraction contract and page ledger before preparing source-linked candidate clauses. Quotations are written only under ignored `local-artifacts/phase3/`; tracked code and tests contain no source quotations.
- Native-text quotation matching is recorded separately from human semantic review. Candidate relationships start unreviewed; a missing certificate citation is explicit and never replaced by an unrelated remedy citation.
- `rules_from_mapping` refuses incomplete/unreviewed packs, missing source notes, mixed source versions, duplicate roles and unreviewed condition definitions. A local reviewed pack does not authorize Salesforce source attestation or Task approval.
- `scripts/conditional_assessment.py` evaluates explicit all-of applicability and exception conditions with true/false/unknown/conflicting outcomes. Current, verified, supplier-scoped evidence is required for each condition. Output includes contributing evidence IDs, cited clause IDs, source version, date and rule version.
- Proposed bid-security exception requires three independently represented concepts: local establishment, SME classification and valid certificate. This is a proposed scenario model requiring source-relationship review, not a universal procurement rule. A separate certificate obligation is conditional on claiming the exemption. These conditions must be explicitly accepted in a reviewed mapping before rule construction.
- Missing exception conditions cannot turn negative direct evidence into a premature gap. An established negative condition can disprove an all-of exemption. Conflicting condition evidence prevents an exemption. Final security has no inherited bid-security exception.

## Existing local source audit

All three user-supplied PDFs and all three saved runs exist. PDF hashes match their manifest identities. No files were uploaded or re-extracted.

| Source | Mapping result |
| --- | --- |
| Software | Two provisional source citations (base security and SME exception); separate certificate citation missing |
| ERP | Two provisional source citations (base security and SME exception); separate certificate citation missing |
| Audit | Stopped: saved result sets award-rule clarification but has no citation for that populated clarification flag; complete extraction contract fails |

The Audit file's source hash and 37-page native ledger match. No source was substituted and no saved model result was edited to bypass the failure. This is a contract-validation gap in the old run, not evidence that its PDF is unreadable. Any future narrowly scoped contract should be explicitly designed and tested; this increment does not silently weaken validation.

The supporting certificate clause needs exact local-source citation and independent relationship review. Prior conversation review of Software page 14 is context, not a machine-importable citation for every booklet. Do not copy that page number across documents. Candidate files remain accepted_for_business_use=false.

## Verification

64 Python tests pass (48 existing + 16 new). New tests cover compound exceptions, conditional certificate applicability, expiry, supplier scope, unverified evidence, conflicts, mixed source versions, duplicate identities, citation gaps and reviewed-pack construction. These are synthetic engineering tests, not held-out accuracy or supplier-eligibility evaluation. Source-containing generated mapping paths are confirmed ignored by Git. No external requests are made by these scripts.

## Next implementation boundary

1. Capture exact certificate evidence from the existing authorized local source and review all clause relationships; no new provider request is needed for Software.
2. Implement matching compound-rule contracts and source-bound import in Apex. Current deployed Apex still uses the simpler single-concept synthetic exception model; it has not been silently upgraded.
3. Add the final evidence table, immutable assessment snapshots and assessment-based approval binding before declaring broader Phase 3 complete.

The reviewed conditional Python engine is a new local module; existing Phase 2/3 deployed behavior and historical Tasks remain unchanged. No org operation was attempted.
