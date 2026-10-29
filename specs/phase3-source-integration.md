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

The original boundary below is historical. The Software-specific implementation and deployment are now recorded in the next section; ERP and Audit remain unchanged.

1. Capture exact certificate evidence from the existing authorized local source and review all clause relationships; no new provider request is needed for Software.
2. Implement matching compound-rule contracts and source-bound import in Apex. Current deployed Apex still uses the simpler single-concept synthetic exception model; it has not been silently upgraded.
3. Add the final evidence table, immutable assessment snapshots and assessment-based approval binding before declaring broader Phase 3 complete.

The reviewed conditional Python engine is a new local module; existing Phase 2/3 deployed behavior and historical Tasks remain unchanged. No org operation was attempted.

## Software source workspace — implemented and deployed October 29

This increment uses the saved Software extraction and native-text ledger only. No new model request or original-PDF Salesforce upload occurred. It remains a source-bound demo with a synthetic supplier, not actual supplier eligibility or an open tender claim.

### Source mapping

- Base bid-security clause: PDF page 15.
- SME exception: PDF page 16.
- Supporting certificate: PDF page 14, section 35(d). The exact clause is extracted locally between section boundaries and retained only in ignored artifacts or the authorized selected-quotation records.
- The certificate condition is **omission of initial security**, represented by OMITS_INITIAL_SECURITY, rather than the less precise earlier CLAIMS_SECURITY_EXEMPTION proposal. It must still be reviewed in context by the user.
- All three source clauses start unverified. No previous real-source record or historical Task was repurposed or modified.

### Implementation

- `prepare_software_workspace.py --as-of YYYY-MM-DD` revalidates source and saved extraction, checks the existing selected-quotation Salesforce grant and prepares three provisional candidates locally. It fails closed if section anchors or role counts are ambiguous. Generic candidate mapping remains provisional; this step does not mark relationships reviewed.
- `import_software_workspace.py --execute` re-prepares/compares the payload and calls only dev-agentforce. No retries, source attestation, approval or Task creation. Generated source-containing JSON, Apex and CLI output remain ignored.
- Apex `importSoftwareWorkspace` validates source identity/version, exact clause roles, explicit historical date and the synthetic supplier identity. It atomically imports and links clauses with a content-based unique workspace key; identical retries reuse a workspace.
- `EtimadCompoundRules` implements the compound-condition behavior in Apex. In source mode, source assessment requires all three accessible clauses to match the workspace and have current human verification. Two findings are produced (security and conditional certificate); the exception clause is supporting context, not a fictitious standalone obligation.
- The SME exception requires local establishment + SME classification + current verified certificate. Missing conditions remain unknown; conflicts block exemption. Expired or wrong-supplier evidence does not qualify. Final security does not inherit this exception.
- Source workspace context fingerprints include all three source revisions and verification states. Any source correction blocks the dependent findings until reviewed again. Existing unlinked Phase 2 fingerprints and synthetic demo mode remain compatible.
- Added Source_Model__c and unique Source_Key__c fields plus Phase3 Data/Read grants. The UI explains the source-mode conditions. Its JSON evidence editor remains an interim developer interface.

### Verified delivery evidence

- First dry run found an Apex test runAs argument typing error; corrected to a typed User variable. No access bypass was used.
- Subsequent dry run `0Affj00000WhErhCAF`: Succeeded, checkOnly=true, all 13 Apex tests passed, no coverage warnings.
- Actual deployment `0Affj00000WgSNGCA3`: Succeeded, checkOnly=false, all 13 Apex tests passed.
- Local verification: 69 Python tests and 13 Jest tests passed; diff whitespace checks passed. Tests use invented quotations only.
- Import succeeded for EA-00001, SYNTHETIC-SOFTWARE-SUPPLIER, explicit historical assessment date 2026-03-12. No supplier evidence was fabricated as verified; initial evidence list is empty.
- Independent read-only query confirmed exactly three linked clauses with pages 15/16/14, zero verified clauses and zero linked Tasks in that workspace. This check did not inspect private source quotation text or authorize any review.

### Still required

The user must review the real Software clauses and their stated relationship in the original PDF, then explicitly verify them. Synthetic supplier assertions can then demonstrate the compound paths; they must not be described as real company evidence. No live real-source assessment result is claimed before that review. Final evidence table, immutable assessment snapshots and assessment-bound approval remain outstanding. No commit or push was made during this increment.

## Automated CLI simulation — October 29, 2026

At the user's explicit request, simulated the review transitions and synthetic supplier assertions through the CLI instead of requiring another UI walkthrough. This is rollback-only integration testing, not human source attestation. It does not persist verified source clauses or certify the original interpretation.

Reusable scripts:

- scripts/simulate_source_workspace.apex — bounded scenarios against EA-00001, calling the same permission-checked service methods; no Task approval action.
- scripts/simulate_source_workspace.py --execute — four sequential batches using explicit dev-agentforce; stops on any failure, with no retries or alternate orgs.

First all-in-one attempt exceeded 100 SOQL queries and failed. It was replaced with smaller bounded transactions, preserving application permission checks and logic. Each successful batch saves the initial workspace/review state, temporarily performs simulated review transitions and supplier assertions, then rolls back and asserts restoration of evidence JSON, workspace revision, clause revision/verification/review metadata, review count and Task count. Temporary review notes explicitly say automated rollback simulation, not human attestation.

All four batches passed:

| Scenario | Security result | Certificate result |
| --- | --- | --- |
| Missing evidence | unknown | unknown |
| Unverified assertions | unknown | unknown |
| All current verified synthetic conditions | not_applicable | supported |
| Expired certificate | unknown | unknown |
| Missing locality | unknown | supported |
| Conflicting locality | conflicting | supported |
| Verified nonlocality + negative security assertion | gap | supported |
| Initial security not omitted | not_applicable under the modeled SME exception | not_applicable |

Each batch additionally simulated a source correction and confirmed SOURCE_RELATIONSHIPS_NOT_REVIEWED before rolling back. Four successful rollback checks confirm no persistent automated source/evidence attestation and unchanged accessible Task/review counts. No original source text was logged by the simulation; raw CLI results stay ignored under local-artifacts/phase3/cli-simulation/.

The automated check replaces the additional manual workflow exercise for this demo, not human judgment about clause meaning. Source clauses in EA-00001 remain in their initial review state. No commit or push is included in this simulation increment.

## Phase 3 closure: evidence table, immutable snapshots, and version-bound approval — October 29, 2026

All three remaining broader Phase 3 pieces have been implemented, deployed, and verified against `dev-agentforce`.

1. **Reviewer-friendly evidence table:**
   - Upgraded LWC `etimadAssessment` replacing the raw JSON textarea with an interactive `lightning-datatable`, inline row forms, date validation, and discard handlers.
   - 21 Jest unit tests pass locally (`etimadEvidence.test.js`, `etimadAssessment.test.js`, `etimadReview.test.js`).

2. **Immutable assessment snapshots:**
   - Deployed `Etimad_Snapshot__c` custom object and fields with `EtimadSnapshotTrigger` blocking updates/deletes.
   - Implemented `EtimadDecisionService.capture` generating cryptographically hashed immutable snapshot records (`Context_Hash__c`).

3. **Version-bound assessment approval:**
   - Deployed `Etimad_Approval__c` custom object with `EtimadApprovalTrigger` blocking updates/deletes.
   - Implemented `EtimadDecisionService.approve` enforcing strict version matching between snapshot context and current workspace/evidence/source revisions. Rejects unresolved, unreviewed, or stale assessments.
   - Assigned `Etimad_Decision_Data` and `Etimad_Decision_Read` permission sets.

4. **Verified deployment and CLI simulation:**
   - Dry run `0Affj00000WjWsXCAV`: 18/18 Apex tests passed.
   - Deployment `0Affj00000WjX8fCAF`: 76 components deployed, 18/18 Apex tests passed.
   - CLI simulation `scripts/simulate_decision_workflow.py --execute`: Passed with verified atomic rollback, 0 persistent approvals, 0 persistent attestations, 0 tasks created.
   - 75 Python tests passed.
