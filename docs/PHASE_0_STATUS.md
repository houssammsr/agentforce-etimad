# Phase 0 — verified capability report

Date: October 28, 2026. Status: Salesforce feasibility demonstrated; external document processing and benchmark checks remain pending.

## Accounts and tools

| Check | Observed result |
| --- | --- |
| GitHub CLI | houssammsr active; rocky24m, berennicem26 and houssamm26 also authenticated but inactive |
| Git | 2.53.0.windows.1 |
| Repository | Folder was not a Git repository; no init, commit, push or remote changes performed |
| Java / javac | Temurin 21.0.12.1 |
| JAVA_HOME | Points to installed Eclipse Adoptium JDK 21; Salesforce VS Code Java setting matches |
| Salesforce CLI | 2.155.8; CLI reports embedded Node v24.22.1 |
| Shell Node | v22.20.0; distinct from CLI runtime |
| Python | 3.13.7 |
| Agent CLI plugin | 2.2.2 core; validate/publish/preview and newer test-runner flags present |
| Code Analyzer | 5.16.0 installed; analysis not yet run because no Apex/LWC business implementation exists |
| VS Code | Salesforce extension pack, Apex, LWC, org tools, Agentforce agents, Agent Script language client, SLDS and Code Analyzer installed |

No credential values or authentication exports are stored in this report.

## Connected Salesforce org

- Explicit alias/default: dev-agentforce.
- Live Organization query succeeded: Developer Edition, IsSandbox=false.
- Metadata discovery exposes AiAuthoringBundle, AiTestingDefinition, GenAiPromptTemplate, GenAiFunction and GenAiPlugin.
- Existing Arabia_Quoting_Agent versions were observed and left unchanged.
- PermissionSet schema exposes agent-builder, service-agent and prompt-template management permissions. The user's prior permission verification is noted; individual effective permission assignments were not separately re-audited here. Successful Etimad publication/activation independently demonstrates the necessary path for this probe.
- At the storage check: DataStorageMB max=5, remaining=4; FileStorageMB max=20, remaining=20; DailyApiRequests max=15000, remaining=14980. These are snapshots, not reserved capacity.

Storage decision: keep the first fixture small. Measure storage per section/requirement/document before ingesting real packs. Do not assume the Developer Edition can hold a representative corpus or hundreds of duplicated long-text sections. Larger originals may require authorized external storage and controlled references later; no external storage was provisioned here.

## Live agent proof

Created a separate EtimadFeasibility employee agent with no business actions. Published and activated version 1. This is an internal read-only feasibility probe, not the final tender agent or an external deployment.

Commands exercised:

```powershell
sf agent validate authoring-bundle --api-name EtimadFeasibility --target-org dev-agentforce --json
sf agent publish authoring-bundle --api-name EtimadFeasibility --target-org dev-agentforce --json
sf agent activate --api-name EtimadFeasibility --version 1 --target-org dev-agentforce --json
sf agent preview start --api-name EtimadFeasibility --target-org dev-agentforce --json
```

Validation, publication, activation and published-agent preview all succeeded. Publication retrieved generated AiAgentDefinition/AiAgentDefinitionVersion metadata, rather than assuming the older Bot layout. Generated agent configuration has logPrivateConversationData=false; this is not a claim about every provider/platform retention path.

Observed smoke checks in one session:

| Input | Observed behavior |
| --- | --- |
| English capability question plus unknown submission deadline | English response; explicitly said no tender was loaded and did not invent a deadline |
| Arabic question asking deadline, approval and opportunity creation | Arabic response; said documents were missing and could not approve or create an opportunity |

Session was closed. Traces are under ignored .sfdx/. This is two manually inspected smoke checks, not a multilingual accuracy benchmark, injection test suite or end-to-end action test.

## CLI issue and working path

Local authoring-bundle preview failed after successful compilation with: Cannot read properties of undefined (reading 'replace'). Inspection of installed @salesforce/agents scriptAgent.js showed startPreview calls .replace on globalConfiguration.defaultAgentUser without first checking that it exists. The minimal employee agent has no dedicated agent-user setting.

Working path: publish/activate the dedicated probe, then preview by --api-name. No CLI source changes, fake agent user or system-wide plugin upgrades were made. A first syntax error from a quoted reasoning instruction was corrected to the required template block; subsequent org compilation passed.

## Remaining feasibility gates

1. External Gemini — UPDATED: the user supplied a paid Google Cloud project and API-key configuration. A Git-ignored local .env now configures the project-scoped Vertex global endpoint. One synthetic Arabic schema probe passed with HTTP 200 and returned modelVersion gemini-3.8-flash. Binding/IAM and project logging settings were not independently inspected. See docs/VERTEX_INTEGRATION.md. Rotate the chat-exposed key locally.
2. Native PDF benchmark — UPDATED: after explicit user authorization, three full government PDFs (134 pages total) were sent directly as inline PDF inputs. All requests returned HTTP 200 and STOP; 29/30 selected candidate field comparisons matched literally, with the remaining ERP reference differing only in whitespace. This is not whole-document recall or independently adjudicated accuracy. Exact quotation verification and failure-path tests remain open. See docs/VERTEX_PDF_RESULTS.md.
3. Calendar converter: select/pin an Umm al-Qura implementation and test independently verified reference pairs, invalid dates and supported range.
4. Agentforce automated runner: newer runner flags and metadata discovery are verified, but AiTestingDefinition list was empty. No batch test was created/run. Verify actual runner support in this non-sandbox Developer Edition rather than infer it from CLI availability.
5. Persistence/storage: measure a tiny Requirement/Section fixture before settling field sizes and retention.
6. Permission isolation: verify business-object access under restricted identities once objects/actions exist; the current probe has no data actions.

Do not mark all of Phase 0 complete until the external parsing, calendar, storage and testing-environment checks are resolved.
