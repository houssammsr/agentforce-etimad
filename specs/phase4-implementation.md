# Phase 4 read-only slice — implementation status

Updated October 30, 2026. Action package deployed; assistant v2 published and active. Historical local-only status and blocker below are superseded by the update at the end.

## Included

- EtimadComplianceAction: one narrow invocable method, read-only custom-permission/user-mode queries, ordered responses, explicit record selection, optional stale-revision rejection and scoped source citations.
- Uses existing EtimadCompoundRules and evidence parsing. Source-model support is deliberately SOFTWARE_SECURITY_V1 only; the separate generic synthetic workspace returns UNSUPPORTED_MODEL, not a substitute assessment.
- At most 200 request entries and ten distinct workspaces, two bulk queries and no DML. Excess source dependencies fail closed rather than silently assess a truncated set.
- Returns historical assessment date, synthetic supplier warning, source review status, source version, context fingerprint and two obligation findings. Never returns raw evidence JSON or snapshot payloads.
- Five Apex tests authored for bulk behavior/read-only execution, stale context, missing evidence, invalid/unsupported IDs/models, custom permissions and private records. These are not executed until org validation succeeds.
- EtimadBidAssistant authoring bundle, separate from feasibility/Arabia, with a forced entry transition and only the read action. Prompts preserve scope, provisional status, original Arabic and no-write boundaries.
- New Etimad_Agent_Read permission set grants only action-class access. Users also require existing Etimad_Reader and Etimad_Phase3_Read data permissions and sharing. No new broad data access.
- Four AiTestingDefinition boundary smoke cases authored, not run. These tests without a selected workspace cover abstention/no-tool behavior only. They do not prove live data retrieval or absence of database writes; the latter is covered by Apex assertions and must also be checked in live preview.

## Validation blocker

Fresh local checks: 75 existing Python tests passed; 21 existing LWC tests passed; diff whitespace check passed. The installed Salesforce agents SDK parsed the new AiTestingDefinition and validated its four-case NGT spec locally. This establishes format only, not scorer execution or agent compilation. Final PMD Recommended scan found two moderate CyclomaticComplexity findings (class total 40; summarize method 14); no high/critical findings. These remain visible rather than suppressed. New Apex tests require Salesforce and have not run.

Automatic approval review rejected the command containing the Salesforce dry-run operation before execution, with no specific reason beyond blocked by policy. No alternate execution path was used. Local files and checks continue; no Salesforce deployment, permissions assignment, publication or activation occurred in this slice.

## Next validation steps

First run the narrow Apex/permission-set dry run from this workspace:

```powershell
sf project deploy start --manifest manifest/phase4-actions.xml --target-org dev-agentforce --dry-run --test-level RunSpecifiedTests --tests EtimadComplianceActionTest --wait 10
```

Inspect failures before actual deployment. Stop on account/restriction issues. After a successful deployment of these prerequisites, validate the separate agent:

```powershell
sf agent validate authoring-bundle --api-name EtimadBidAssistant --target-org dev-agentforce
```

Do not publish until action discovery/type binding and source scope are verified. If validation succeeds, publish/activate only this new agent, then test read-only actions using an explicitly selected accessible workspace. Test unreviewed real-source context without attesting it. Do not substitute preview simulation for live action execution.

New Studio smoke metadata targets v1; reconcile it with the actual published version before deployment. Verify supported scorer names/empty action-sequence semantics in the target runner. Add live fixtures for historical date, citations, stale context and cross-workspace denial; keep private source content and org-specific generated artifacts ignored.

Opportunity creation, human attestation and assessment approval are not conversational tools in this slice. No commit or push.

## October 30 — deployment and scope-language correction

- User-supplied dry-run 0Affj00000WocajCAB succeeded, five Apex tests passed.
- User-supplied actual deployment 0Affj00000WnA74CAF succeeded, five Apex tests passed. User published/activated assistant v1.
- Assigned Etimad_Agent_Read successfully using explicit dev-agentforce.
- Published-agent v1 preview exposed a capability-language ambiguity: the whole-tender question elicited a request for an ID without clearly stating whole-tender eligibility remains unsupported.
- Confirmed published v1 retained the scope instructions; the failure was not explained by an absent scope instruction. The generic missing-ID instruction competed with the capability restriction. No source-retrieval action had been exercised in this check.
- Strengthened the local subagent scope/description and replaced generic missing-data guidance with capability-first guidance and English/Arabic examples. No additional permissions or write actions were introduced. Whole-tender eligibility is explicitly unsupported even with an ID or two passing findings.
- Added two bilingual regression cases and tightened case 1 to reject conditional eligibility promises. Updated smoke target to v2. Installed SDK local format validation passed all six cases; Studio scorers have not been executed.
- Agent bundle validation passed; publication succeeded; activation confirmed v2.
- Live published-agent preview: original English question, English follow-up asking whether both checks certify eligibility, and Arabic ID/whole-tender paraphrase all explicitly rejected whole-tender assessment and offered only the two supported findings. Preview sessions were closed. This is three observed responses, not a statistical reliability guarantee or a full action evaluation.
- No business-data mutation action was invoked. End-to-end live source lookup, full scorer execution and the remaining Phase 4 work are still pending. No commit/push.

Research: Salesforce's August 20, 2026 troubleshooting guidance recommends locating the failure via execution path, repeating inputs/paraphrases, verifying activated versions, and keeping critical validation in deterministic controls. Reference: https://help.salesforce.com/s/articleView?id=005391239&language=en_US&type=1

## October 30 — Arabic procurement terminology

Added explicit procurement terminology in agent instructions and the read-action description: BID_SECURITY means الضمان الابتدائي (financial bid guarantee), not cybersecurity. Combined scope is متطلبات الضمان الابتدائي والشهادة المشروطة. Added a seventh bilingual terminology smoke case; local SDK format validation passed, not live Studio scorer execution.

Bundle validated, published and activated as v3. A fresh live Arabic workspace lookup used the correct combined scope and preserved unknown findings, unreviewed source status, historical date and synthetic supplier labels. It also unexpectedly reproduced source quotations despite the user's no-quotation request. Stopped further tests and closed the preview session. Do not label this a complete response-format pass. No business mutation, source attestation, commit or push.
