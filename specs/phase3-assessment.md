# Phase 3 â€” linked requirements and supplier evidence

Phase 2 is complete for its demonstrated requirement â†’ review â†’ approval â†’ Task scope. Non-admin UI and Vertex retention checks are outside that sign-off and remain unverified. No new cloud processing is performed here.

## Current verified status — October 29, 2026

The bounded synthetic Salesforce assessment slice is deployed and has been exercised by the user in the UI. This is not completion of the broader source-derived Phase 3 scope or a production-readiness claim.

| Check | Result and evidence |
| --- | --- |
| Successful dry run | User-supplied CLI output: `0Affj00000WgyzpCAB`, 52 components, 10/10 Apex tests passed |
| Actual deployment | User-supplied non-dry-run CLI output: `0Affj00000Wh07BCAR`, Succeeded, 10/10 Apex tests passed |
| Initial UI state | Workspace EA-00000, source SYN-PHASE3, version synthetic-v1, assessment date 2026-06-01; all three findings unknown / REQUIREMENT_NOT_REVIEWED |
| Reviewed valid evidence | User reviewed the three synthetic requirements and attested SYN-SME, valid 2026-01-01 through 2026-12-31. UI showed BID_SECURITY = not_applicable / REVIEWED_EXCEPTION_SUPPORTED; LOCAL_SME_CERT = supported / VERIFIED_DIRECT_EVIDENCE; FINAL_SECURITY = unknown / NO_CURRENT_VERIFIED_EVIDENCE |
| Expired evidence | User changed validTo to 2026-05-31, saved and re-attested. UI showed all three findings unknown / NO_CURRENT_VERIFIED_EVIDENCE, despite verified=true |
| Revision change | User-pasted UI showed a different workspace revision after editing evidence; findings carried the updated workspace/requirement revision pair |

Evidence above is from user-provided CLI/UI transcripts, not independent assistant org queries. No Task approval was requested during these scenarios; Task counts were not independently checked. The existing real-source review remained visible with its historical Task-created state; its underlying data was not independently compared. The synthetic UI checks establish scoped exception and expiry behavior, not real supplier eligibility, citation accuracy or customer impact.

Commit history: offline foundation/Phase 2 closure `0eebcea`; initial integration `d4794dd`; refresh/draft/unresolved-exemption fixes `56675cf`. This update records the later deployment fixes, diagnostics and live demonstration. No push is included.

## Implemented first slice

`scripts/assess_requirements.py` provides an offline deterministic assessment domain with typed, immutable requirements, evidence and results. Multiple requirements share supplier-scoped evidence. Each result records source version, assessment date, reason, evidence IDs and rule version.

Synthetic scenario: a bid-security requirement explicitly links to a reviewed local-SME certificate exception. Valid verified positive evidence makes that requirement not applicable and supports the separate certificate requirement. It does not exempt final security. These are authored fixture relationships, not inferred Saudi law or a finding about an actual supplier.

Results: supported, gap, unknown, conflicting, not_applicable. Missing, expired, future, unverified or another supplier's evidence never establishes compliance. Verified negative evidence can establish a gap. Conflicting exception evidence blocks exemption. Stale or unreviewed requirements yield unknown. Explicit historical dates avoid accidentally evaluating old tenders as of today.

Eight new synthetic tests plus the existing suite pass: 46 Python tests. This does not establish extraction accuracy or real-world eligibility.

## Remaining Phase 3 integration

- Model conditional certificate obligations and exception predicates explicitly; this first slice accepts only reviewed direct concept links.
- Map saved authorized candidate extraction to reviewed requirements, retaining every source citation and exception relationship. Do not silently mark candidates reviewed.
- Bounded Salesforce persistence and deterministic Apex assessments are implemented and exercised for synthetic fixtures; broader source-derived mapping remains outstanding.
- Replace the implemented developer-oriented JSON editor with the final reviewer table. Preserve human verification and atomic approved Task creation; assessment results must not grant approval.
- Persist supplier/evidence revisions as well as source revisions before integrating approvals; evidence changes must invalidate affected assessments.
- Synthetic integration testing is demonstrated above; validate source-derived requirements and remaining scope before declaring broader Phase 3 complete.

## Salesforce integration implementation â€” October 29

The offline slice and Phase 2 closure were committed at user request as `0eebcea`. Nothing was pushed. The first Salesforce integration slice was subsequently committed as d4794dd. The review fixes described below were committed as `56675cf`.

Implemented locally:

- Private Etimad_Assessment__c aggregate with explicit supplier, historical assessment date, source/version and bounded evidence JSON (20 items, 16,000 characters).
- Assessment__c and Exception_Concept__c links on requirement reviews. Existing unlinked Phase 2 fingerprints are preserved.
- EtimadAssessmentService: user-mode, permission-checked actions; deterministic assessment parity; evidence edits clear verification; explicit attestation and revision-checked writes; direct DML blocked by trigger.
- Assessments recompute from current source verification and evidence instead of persisting potentially stale statuses. Combined workspace/requirement revisions accompany findings. Evidence changes invalidate displayed results in the editor. Historical findings are not approval records.
- Synthetic workspace factory creates three unverified fixture requirements and one unverified evidence item. No real evidence is auto-attested. No assessment action creates a Task.
- New bilingual assessment panel above the existing review panel: refresh, create synthetic example, select workspace, edit evidence, attest a synthetic item, recompute findings. The initial evidence editor is a developer-oriented JSON editor, not the final business-user table. Use the existing review panel's Refresh after creating the example, then manually verify fixture requirements there.
- Permission-set additions and an explicit Etimad-only manifest at manifest/phase3.xml. Unrelated Arabia test metadata is excluded.

Verification: 46 Python tests and 10 Jest tests pass. Three new Apex tests cover scoped exceptions, requirement review prerequisites, evidence edit invalidation, stale writes, conflict, expiry, direct-write rejection and supplier mismatch. This was the initial local-only checkpoint; current org results are recorded above.

First Salesforce dry-run `0Affj00000WfVIMCA3` failed on permission XML ordering; checkOnly=true, no deployment. XML ordering was repaired locally. Automatic approval review rejected the combined follow-up repair/test/validation command without a specific rationale. Local repair and tests were completed separately; no Salesforce retry or actual deployment followed. This historical blocker was followed by user-run validation and deployment, recorded above.

Validation command for the user to run:

```powershell
sf project deploy start --manifest manifest/phase3.xml --target-org dev-agentforce --dry-run --test-level RunSpecifiedTests --tests EtimadReviewControllerTest --tests EtimadAssessmentTest --wait 10
```

The synthetic integration is now deployed; broader Phase 3 is not complete. Full source-derived exception mapping, conditional compound predicates, immutable assessment history/approval binding and final reviewer table remain future work. Current Task approval continues to authorize only an internal requirement-level follow-up; it does not endorse an assessment or bid pursuit. No real-document upload or unrelated org change was made.

## Integration review fixes â€” October 29, 2026

Implemented after code review:

- listWorkspaces is now a non-cacheable imperative Apex read so post-save/attestation reloads fetch current server data.
- Unsaved evidence disables assessment, attestation, workspace switching, refresh and example creation. Explicit Discard restores saved evidence; Save remains available. Handler guards enforce this even if a disabled button event is dispatched.
- A workspace revision change detected during the assessment/reload sequence discards findings rather than displaying them beside a different evidence revision.
- Python rule version phase3.2 and Apex now return unknown / EXCEPTION_APPLICABILITY_UNRESOLVED when verified direct negative evidence exists but a linked exception has no current verified evidence. Verified negative exception evidence resolves that condition, permitting a gap. Positive direct evidence still supports the requirement; a supported exemption still makes it not applicable.
- Regression tests cover unsaved drafts, discard, new server revisions after save, changed revisions during assessment, unresolved exception evidence and resolved negative exceptions. A matching Apex regression test was added.

Verification: 48 Python tests and 13 Jest tests passed; git diff --check passed. The four Phase 3 Apex tests subsequently passed alongside six Phase 2 tests in user-run validation and deployment. These review fixes were committed as `56675cf`; no push is recorded. The earlier assistant-side automatic approval rejection is historical; the user executed the later commands. Phase 2 remains intact; no real source data or provider calls were used for these fixes.

## Deployment diagnostics and query fix

Dedicated Etimad_Phase3_Data and Etimad_Phase3_Read permission sets and an optional foundation manifest are included. Apex tests explicitly assert expected assignments, custom permissions, schema and CRUD/FLS grants before business operations. These additions do not establish the original permission failure's root cause.

Dry run 0Affj00000WgvDyCAJ passed six tests and failed four on a separate unqueried-field defect. createDemo now selects nullable Exception_Concept__c before passing queried rows to linkSynthetic. Regression assertions verify all three fixture links and restrict the SME exception to bid security. Subsequent validation/deployment passed all ten tests. No system-mode application fallback or unrelated Arabia change was introduced.
