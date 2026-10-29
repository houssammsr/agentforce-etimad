# Phase 0/1 foundation hardening

October 28, 2026. Phase 2 has not started. No business objects, Apex actions or review UI added.

## Changes

- PDF uploads now check the recorded grant before network access: source ID, SHA-256, provider, project, location and feasibility purpose. The full manifest is preflighted before the first upload; the callable probe also checks authorization. `--allow-upload` remains required for CLI execution. A modified PDF needs a new authorization record based on explicit permission, not just an updated manifest.
- Response validation requires citations for every populated factual field and for an affirmative award-rule ambiguity flag. The live probe rejects out-of-range pages before returning a result. Null facts require no evidence. Multiple citations may support the same field. These are structural checks; quotation support and semantic interpretation remain separate review gates. Probe results explicitly remain unaccepted for business use.
- SME exemption and remedy expectations now come from each document's candidate annotations. They remain candidates, not independently reviewed gold.
- Paired baseline trials require an annotation version and explicit JSON assertion-ID list. A canonical hash of the version and sorted unique IDs must match across manual/assisted trials; counts must agree with the IDs. This verifies scope identity, not review correctness. The CSV is empty and still reports `not_measured`.
- Added `normalize_calendar.py` with pinned `hijridate==2.5.0`. It accepts explicit Hijri year/month/day, Arabic/Persian or ASCII digits, and optional era markers. It preserves the original literal and returns both normalized dates without inferring time/timezone. Invalid or ambiguous dates fail; project range is deliberately restricted to 1440–1500 AH. No Salesforce fields are deployed.

## Calendar evidence and limits

Install with `python -m pip install -r requirements.txt`.

The maintainer documents a table-based Umm al-Qura implementation and a broader 1343–1500 AH range: https://github.com/dralshehri/hijridate . The project restricts historical input rather than claiming suitability for all historical Saudi dates.

Eighteen first-of-month reference pairs across 1440, 1445, 1448, 1450, 1499 and 1500 were generated independently with Windows .NET `System.Globalization.UmAlQuraCalendar`; all match. An Arabic-digit example also matches the maintainer's documented 1445-06-15 → 2023-12-28 example. This is independent implementation corroboration, not independently adjudicated government reference data. Calendar/source conflicts must still go to review.

## Verification boundary

29 local tests pass, including authorization changes, missing field evidence, invalid pages, annotation-derived expectations, equal-count/different-scope rejection, calendar references and invalid dates. Dataset validation with all three source hashes/page ledgers passes. No new model uploads were required.

Synthetic tender regression fixtures and supplier evidence remain prepared data, not executed model-behavior evaluations. Prompt-injection resistance, exception handling and supplier assessment are not claimed as verified. Those evaluations need the later extraction workflow; Phase 2 remains unstarted.

The Agentforce beta runner was attempted using only the separate read-only EtimadFeasibility agent and two synthetic Arabic/English cases (`specs/etimad-feasibility.yaml`). `sf agent test run-eval --spec specs/etimad-feasibility.yaml --api-name EtimadFeasibility --target-org dev-agentforce --json` produced no result for more than three minutes; the local CLI process was stopped. Server-side completion is unknown. No alternate runner or agent was attempted. This does not establish an account restriction or a successful evaluation. Local CLI source inspection shows this runner resolves BotDefinition/BotVersion, whereas this project's publication retrieved AiAgentDefinition metadata; compatibility remains uncertain. Runner feasibility remains OPEN and requires diagnosis before Phase 2. CLI documentation: https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference_agent_test_run-eval.html .
