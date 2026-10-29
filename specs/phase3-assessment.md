# Phase 3 — linked requirements and supplier evidence

Phase 2 is complete for its demonstrated requirement → review → approval → Task scope. Non-admin UI and Vertex retention checks are outside that sign-off and remain unverified. No new cloud processing is performed here.

## Implemented first slice

`scripts/assess_requirements.py` provides an offline deterministic assessment domain with typed, immutable requirements, evidence and results. Multiple requirements share supplier-scoped evidence. Each result records source version, assessment date, reason, evidence IDs and rule version.

Synthetic scenario: a bid-security requirement explicitly links to a reviewed local-SME certificate exception. Valid verified positive evidence makes that requirement not applicable and supports the separate certificate requirement. It does not exempt final security. These are authored fixture relationships, not inferred Saudi law or a finding about an actual supplier.

Results: supported, gap, unknown, conflicting, not_applicable. Missing, expired, future, unverified or another supplier's evidence never establishes compliance. Verified negative evidence can establish a gap. Conflicting exception evidence blocks exemption. Stale or unreviewed requirements yield unknown. Explicit historical dates avoid accidentally evaluating old tenders as of today.

Eight new synthetic tests plus the existing suite pass: 46 Python tests. This does not establish extraction accuracy or real-world eligibility.

## Remaining Phase 3 integration

- Model conditional certificate obligations and exception predicates explicitly; this first slice accepts only reviewed direct concept links.
- Map saved authorized candidate extraction to reviewed requirements, retaining every source citation and exception relationship. Do not silently mark candidates reviewed.
- Add bounded Salesforce persistence and Apex assessment parity, respecting the small org storage allowance. Python inputs alone are not an authorization boundary.
- Extend the LWC to display linked findings/evidence and their provenance. Preserve human verification and atomic approved Task creation; assessment results must not grant approval.
- Persist supplier/evidence revisions as well as source revisions before integrating approvals; evidence changes must invalidate affected assessments.
- Test this integrated workflow in dev-agentforce with synthetic data before treating Phase 3 as complete.

No Salesforce deployment, real-document model call, commit or push is included in this slice. The Phase 2 components and unrelated Arabia metadata are unchanged.
