# Phase 2 — evidence review walking skeleton

Implementation date: October 29, 2026. Current status: deployed to dev-agentforce; one provisional source-derived requirement imported. Human evidence review and live Task creation remain pending. Not production-ready.

Live deployment update: the user executed deployment job `0Affj00000WeCODCA3`. A read-only report confirmed Succeeded, checkOnly=false, six tests completed and zero errors. This resolves the earlier deployment block for this version; no alternate deployment path was used by the assistant. Etimad_Importer and Etimad_Reviewer were assigned to the current user. One requirement was imported from the existing authorized Software extraction, record ET-00000, PDF page 15. Verification, approval and Task fields were confirmed empty. The Etimad Reviews tab was opened. A repeated import left the review count at one. No evidence was attested to and no Task was created.

Storage before/after: DataStorageMB max 5 / remaining 4; FileStorageMB max 20 / remaining 20. The coarse MB-level limits did not change and do not establish precise bytes per record. Original PDFs were not uploaded to Salesforce, and no new model request was made.

Update, October 29: the user fixed the tab motif to `Custom9: Lightning` and excluded `**/__tests__/**` in .forceignore. Their subsequent org validation was independently confirmed with a read-only deployment report: job `0Affj00000WddlSCAR`, Succeeded, checkOnly=true, 37 components, six Apex tests completed, zero test errors. This establishes org compilation and passing Apex test execution for that validation; it does not persist metadata or establish a live deployed review workflow. A non-dry-run deployment remains unverified.

## Scope

One selected requirement per review record: existing authorized native-PDF extraction → offline candidate preparation → explicit Salesforce import → Arabic/English LWC review → human source attestation → authorized internal Task creation. EtimadFeasibility remains read-only and unchanged. No existing Arabia components are included in the Phase 2 manifest.

The deliberately small Etimad_Review__c aggregate contains source identity/version, fact, quotation, page, revision and decision metadata. This avoids prematurely building a full document/requirements schema in the small Developer Edition. It is not the final normalized application schema. The interface is requirement-level review, not approval to pursue an entire tender.

## Files and boundaries

- manifest/phase2.xml explicitly selects only the new Etimad object, classes, trigger, permissions, LWC and tab.
- EtimadReviewController uses custom permissions, sharing and user-mode database operations. Row locks serialize approvals. Import keys deduplicate repeated content; reuse for changed content fails. Review/task changes are atomic with rollback.
- EtimadReviewGuard blocks direct record writes outside service methods. Fact corrections change the revision and invalidate verification/approval. Existing tasks remain historical and prevent automatic duplicate creation after a correction; manual reconciliation is required.
- Etimad_Importer imports provisional data. Etimad_Reviewer verifies and approves. Etimad_Reader has read-only access to shared/owned records. Permission sets do not grant global access to private records. Task creation also requires underlying Task access from the user's license/profile. No permission sets were assigned during this implementation.
- scripts/phase2_prepare.py validates the source hash, prior grant and saved extraction, and writes one provisional security-rate requirement to ignored local-artifacts/phase2/candidates.json. It does not call the model or send data to Salesforce. It does not transfer deadline values into a security requirement without their own evidence.
- scripts/phase2_import.py checks that the prepared payload is unchanged, checks the Phase 2 Salesforce destination grant, and invokes only the Etimad importer with explicit dev-agentforce. Raw CLI output and anonymous Apex containing the payload remain ignored. No retry, approval or Task creation is performed by that script.
- data/sources/phase2_authorization.json records the user's explicit permission for the same three PDFs through the same Vertex destination and selected requirements/quotations in dev-agentforce. It grants no redistribution or original-PDF Salesforce upload.

## Review behavior

The LWC opens in Arabic RTL and supports English LTR. It displays source ID, version, PDF page, a source link, provisional fact and candidate quotation. The original PDF remains local; the source link points to the recorded buyer URL. Access to that URL is not guaranteed and no bypass is provided. Reviewers must consult the local original if the original authorized source is already locally available; the component does not render local PDFs or assert automated quotation verification.

Correct a fact before verification. Verification requires a note describing how the original page supports it. Approval requires an explicit checkbox and current server-verified revision. Server-side permissions and state remain authoritative; a client flag cannot approve an unverified record. No tasks or reviews are silently auto-approved. A quotation is still provisional even when the JSON shape and page bounds pass.

## Local verification

Observed results on October 29: 38 Python tests passed; five LWC/Jest tests passed; local dataset validation including original PDF hashes/page ledgers passed. Salesforce Code Analyzer Recommended rules on the new Apex classes/triggers reported zero findings after refactoring. This is local static analysis, not org compilation or executed Apex tests. XML structure and Etimad-only manifest selection were checked. One real-source provisional candidate was prepared offline in ignored storage; zero business records/Tasks were written to Salesforce.

Run:

```powershell
python -m unittest discover -s tests -v
python scripts/validate_dataset.py --check-local
npm ci --ignore-scripts
npm run test:unit
python scripts/phase2_prepare.py --source-id TAQEEM-SOFTWARE-2026
```

The preparation command uses the prior ignored extraction result and a local PDF hash; it does not measure a new model run. Source-derived output must never be committed. Python tests use synthetic values. LWC tests use synthetic records and mocked Apex, not an actual Salesforce session.

EtimadReviewControllerTest contains org tests for restricted users, private records, import deduplication, unverified rejection, stale revisions, corrections, repeated approvals, blocked direct writes and payload validation. These tests are written but have NOT run in the org.

## Remaining acceptance gates

1. Resolve the automatic deployment approval block; do not retry through another execution path.
2. Deploy the explicit manifest to dev-agentforce and run EtimadReviewControllerTest. Fix org compilation/permission issues before proceeding. Stop immediately on account restrictions.
3. Assign only the intended Etimad permission sets to authorized test users. Verify actual non-admin access, including a shared read-only record and denied mutations.
4. Record storage before/after one candidate import. No source PDF uploads are necessary.
5. Run phase2_import.py --execute only after deployment and access checks. Verify that the expected one candidate, not a whole corpus, is persisted.
6. Open Etimad Reviews in Salesforce, inspect original evidence, and exercise correction, verification, approval and repeated request behavior. Do not fabricate human review or programmatically attest to unreviewed real evidence.
7. Capture live record/Task counts and denied/stale-write evidence without credentials or source content in tracked files.
8. Verify Vertex-specific logging/retention. Prior Gemini Developer API storage claims do not establish Vertex settings. No new model call was made in this phase.

## Explicit limitations

No automatic ingestion endpoint, Queueable worker, source-file uploader, durable processing-run object, full-tender extraction, addendum supersession across records, conversational business agent, Opportunity creation, or production deployment is included. Source-version changes across separate review records require future document-level supersession handling; current stale checks protect edits to a review. The existing deterministic calendar converter remains available and tested; this security-rate slice does not demonstrate a real Hijri deadline end-to-end.

Native feasibility Studio v2 results reported by the user remain separate from these new business-action tests. The existing v1 test metadata was not rewritten to pretend it reproduces a different Studio workbook.
