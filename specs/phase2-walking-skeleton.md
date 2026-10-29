# Phase 2 — evidence review walking skeleton

Implementation date: October 29, 2026. Current status: deployed to dev-agentforce; one source-derived requirement imported, reviewed by the user and approved for one internal follow-up Task. The bounded live walking-skeleton path has been demonstrated. This does not close every Phase 2 acceptance gate or establish production readiness.

## Verified progress — October 29, 2026

| Item | Status | Evidence / boundary |
| --- | --- | --- |
| Salesforce deployment | Completed | Job 0Affj00000WeCODCA3: Succeeded, checkOnly=false; 37 components |
| Org compilation and Apex tests | Completed | Six tests passed during validation and actual deployment |
| Deployment packaging fixes | Completed | Tab motif Custom9: Lightning; Jest __tests__ excluded from deployment |
| Current-user permissions | Completed | Etimad_Importer and Etimad_Reviewer assigned |
| Real-source candidate import | Completed | ET-00000, Software booklet, PDF page 15; existing authorized extraction reused |
| Duplicate import | Completed | Repeating the import left exactly one review |
| Human evidence review | Completed | User compared source pages 14–16 and submitted the verification note; verified revision matches current revision |
| Explicit Task approval | Completed | User checked the authorization box and clicked approval; approved revision matches current revision |
| Linked Task | Completed | Exactly one matching Task exists, status Not Started |
| Loading recovery fix | Completed for observed flow | Component deployment 0Affj00000WeC88CAF succeeded; user subsequently saw refreshed verified state and completed approval |
| Local Python tests | Completed | 38 passed |
| Local LWC tests | Completed | Eight passed, including timeout, recovery and preservation of drafts |
| Apex static analysis | Completed for Phase 2 Apex | Zero Recommended-rule findings before the frontend-only recovery fix |
| Dataset integrity | Completed | Three PDF hashes and 134-page ledgers validated; 62 candidate assertions and 12 queries; no independent gold or held-out corpus |
| Storage snapshot | Completed, coarse | DataStorageMB 5 max / 4 remaining; FileStorageMB 20 max / 20 remaining, unchanged before/after import |

The Task is an internal follow-up, not a bid approval or submission. The assistant verified records with read-only queries after the user's actions; it did not attest to evidence or approve the real requirement on the user's behalf. Duplicate approval and stale-write handling passed isolated Apex tests; no live concurrency benchmark is claimed. Precise per-record storage was not measurable from the MB-level snapshots.

Historical deployment sequence: the assistant's initial deployment command was blocked before execution. The user fixed the tab style and test-file exclusion, validated job 0Affj00000WddlSCAR (checkOnly=true), then executed the successful non-dry-run deployment. That earlier approval block is no longer an outstanding gate for this deployed version. Original PDFs were not uploaded to Salesforce, and Phase 2 reused the prior extraction without a new model request.

## Scope

One selected requirement per review record: existing authorized native-PDF extraction → offline candidate preparation → explicit Salesforce import → Arabic/English LWC review → human source attestation → authorized internal Task creation. EtimadFeasibility remains read-only and unchanged. No existing Arabia components are included in the Phase 2 manifest.

The deliberately small Etimad_Review__c aggregate contains source identity/version, fact, quotation, page, revision and decision metadata. This avoids prematurely building a full document/requirements schema in the small Developer Edition. It is not the final normalized application schema. The interface is requirement-level review, not approval to pursue an entire tender.

## Files and boundaries

- manifest/phase2.xml explicitly selects only the new Etimad object, classes, trigger, permissions, LWC and tab.
- EtimadReviewController uses custom permissions, sharing and user-mode database operations. Row locks serialize approvals. Import keys deduplicate repeated content; reuse for changed content fails. Review/task changes are atomic with rollback.
- EtimadReviewGuard blocks direct record writes outside service methods. Fact corrections change the revision and invalidate verification/approval. Existing tasks remain historical and prevent automatic duplicate creation after a correction; manual reconciliation is required.
- Etimad_Importer imports provisional data. Etimad_Reviewer verifies and approves. Etimad_Reader has read-only access to shared/owned records. Permission sets do not grant global access to private records. Task creation also requires underlying Task access from the user's license/profile. The importer and reviewer sets were assigned to the current user; actual non-admin UI access remains to be checked.
- scripts/phase2_prepare.py validates the source hash, prior grant and saved extraction, and writes one provisional security-rate requirement to ignored local-artifacts/phase2/candidates.json. It does not call the model or send data to Salesforce. It does not transfer deadline values into a security requirement without their own evidence.
- scripts/phase2_import.py checks that the prepared payload is unchanged, checks the Phase 2 Salesforce destination grant, and invokes only the Etimad importer with explicit dev-agentforce. Raw CLI output and anonymous Apex containing the payload remain ignored. No retry, approval or Task creation is performed by that script.
- data/sources/phase2_authorization.json records the user's explicit permission for the same three PDFs through the same Vertex destination and selected requirements/quotations in dev-agentforce. It grants no redistribution or original-PDF Salesforce upload.

## Review behavior

Loading incident, October 29: after the user's verification click, a read-only org query confirmed ET-00000 had Verified_Revision equal to Revision and a saved verification timestamp; approval and Task fields remained empty. The original component awaited refreshApex without a timeout. The observed stalled browser was not independently reproduced, so the precise platform/network cause is unconfirmed. A bounded recovery fix now times out mutation/refresh waits after 20 seconds, preserves draft notes on failure, displays saved-versus-unknown outcomes, and disables further writes until an explicit successful refresh. It never retries a mutation automatically. Stored reviewer notes are displayed after refresh. Eight LWC tests passed, including hanging mutation/refresh, late wire data, failed refresh and recovery. Only LightningComponentBundle:etimadReview was deployed, job 0Affj00000WeC88CAF, Succeeded, checkOnly=false. The user subsequently confirmed the refreshed verified screen and completed Task approval. The original platform/network cause remains unconfirmed; the fix itself created no Task.

The LWC opens in Arabic RTL and supports English LTR. It displays source ID, version, PDF page, a source link, provisional fact and candidate quotation. The original PDF remains local; the source link points to the recorded buyer URL. Access to that URL is not guaranteed and no bypass is provided. Reviewers must consult the local original if the original authorized source is already locally available; the component does not render local PDFs or assert automated quotation verification.

Correct a fact before verification. Verification requires a note describing how the original page supports it. Approval requires an explicit checkbox and current server-verified revision. Server-side permissions and state remain authoritative; a client flag cannot approve an unverified record. No tasks or reviews are silently auto-approved. A quotation is still provisional even when the JSON shape and page bounds pass.

## Local verification

Latest observed results: 38 Python tests passed; eight LWC/Jest tests passed; local dataset validation including PDF hashes/page ledgers passed. Salesforce Code Analyzer Recommended rules on Phase 2 Apex classes/triggers reported zero findings. XML and Etimad-only manifest selection were checked. Six isolated Apex tests passed in the org. Live data consists of one user-reviewed requirement and one user-approved linked Task. Local tests and static analysis do not establish production readiness.

Run:

```powershell
python -m unittest discover -s tests -v
python scripts/validate_dataset.py --check-local
npm ci --ignore-scripts
npm run test:unit
python scripts/phase2_prepare.py --source-id TAQEEM-SOFTWARE-2026
```

The preparation command uses the prior ignored extraction result and a local PDF hash; it does not measure a new model run. Source-derived output must never be committed. Python tests use synthetic values. LWC tests use synthetic records and mocked Apex, not an actual Salesforce session.

EtimadReviewControllerTest contains org tests for restricted users, private records, import deduplication, unverified rejection, stale revisions, corrections, repeated approvals, blocked direct writes and payload validation. These six tests passed in the successful dry-run validation and actual deployment; they use isolated synthetic records and runAs users.

## Current acceptance checklist

### Completed

- [x] Deploy only Etimad Phase 2 metadata to dev-agentforce; preserve Arabia agents and the read-only feasibility agent.
- [x] Resolve tab style and Jest deployment packaging issues.
- [x] Pass org compilation and all six Apex tests.
- [x] Record the user's Phase 2 source/destination authorization.
- [x] Assign importer/reviewer permissions to the current user.
- [x] Prepare and import one real-source requirement without tracking source content or uploading the original PDF to Salesforce.
- [x] Repeat import and confirm exactly one review remains.
- [x] Record storage limits before and after import, with measurement precision stated.
- [x] Have the user review the original evidence and save a verification note.
- [x] Confirm verified revision equals the current revision.
- [x] Have the user explicitly authorize and approve one internal Task.
- [x] Confirm approved revision, Task linkage and exactly one matching Task.
- [x] Deploy bounded loading recovery and confirm the user can resume the workflow.
- [x] Pass 38 local Python tests and eight LWC tests.
- [x] Pass isolated org tests for private-record access, denied actions, stale revisions, unverified approval, direct-write rejection and repeated approval.
- [x] Consolidate the completed implementation and evidence in this handoff.

### Still required for bounded Phase 2 sign-off

- [ ] **Actual non-admin UI integration:** use an authorized available test identity; show an explicitly shared read-only review, hide unrelated private records, and deny verification/approval without permission. Existing runAs tests cover the server-side subset. Do not create or impersonate users without authorization.
- [ ] **Controlled failure and recovery:** use synthetic data to demonstrate invalid/out-of-range/changed-source input rejection with unchanged prior record/Task counts, followed by valid-input recovery. Do not corrupt ET-00000 or reupload real PDFs for this test.
- [ ] **Vertex-specific logging/retention:** verify the exact project's endpoint and applicable storage/logging/upload/cache settings before further real-document processing. Gemini Developer API defaults do not establish Vertex settings. If access is missing, report it before changing provider or workflow.
- [ ] **Final sign-off:** add evidence for those remaining checks and explicitly mark the bounded slice complete, retaining the limitations below. This documentation update is complete; final acceptance is not.

### Deferred; not new blockers for the one-requirement skeleton

- Precise storage sizing before larger ingestion.
- Broader independent gold labels, held-out corpus and customer timing/impact measurements.
- Full-document extraction, cross-document addenda supersession and automated ingestion.
- Real Hijri-deadline integration, broader multilingual retrieval benchmarking and a conversational business agent.

## Explicit limitations

No automatic ingestion endpoint, Queueable worker, source-file uploader, durable processing-run object, full-tender extraction, addendum supersession across records, conversational business agent, Opportunity creation, or production deployment is included. Source-version changes across separate review records require future document-level supersession handling; current stale checks protect edits to a review. The existing deterministic calendar converter remains available and tested; this security-rate slice does not demonstrate a real Hijri deadline end-to-end.

Native feasibility Studio v2 results reported by the user remain separate from these new business-action tests. The existing v1 test metadata was not rewritten to pretend it reproduces a different Studio workbook.
