# Phase 1: customer workflow and business hypothesis

Status: document-backed development brief; no customer interviews or measured customer baseline yet. Initial persona is a Saudi IT-services supplier bid manager. The pilot focuses on software/ERP operations and related IT audit. Taqeem booklets are government-buyer documents governed by the buyer's stated procurement regulations; do not assume a particular portal or universal statutory rule from their appearance.

## Decisions the product supports

| Step | Owner to validate in interview | Inputs | Reviewable output |
| --- | --- | --- | --- |
| Intake | Bid coordinator | Booklet, attachments, source URL, version | Complete document inventory, dates, processing gaps |
| Initial fit | Bid manager + delivery lead | Scope, company capability | Pursue/review/decline recommendation with reasons |
| Requirements review | Bid manager + compliance reviewer | Source clauses, exceptions, documents | Requirements matrix with original page access |
| Evidence matching | Compliance/HR/finance owners | Registration, applicable certificates, team CVs, SME evidence | Supported/gap/unknown/conflicting/not-applicable outcomes |
| Clarification | Authorized bid manager | Conflicting provisions, unclear times, missing source facts | Draft questions for buyer; never automatically send |
| Pursuit decision | Authorized decision maker | Reviewed findings, costs, capability | Durable approval/rejection tied to source versions |
| Internal execution | Bid coordinator | Approved action payload | One opportunity and assigned evidence-collection tasks |

These roles are proposed personas, not observed customer staffing. Pricing, external submission and legal certification remain out of scope.

## Findings that materially affect the product

- Read the actual booklet's clause, conditions and exceptions together. A missing initial guarantee is not automatically disqualifying for every supplier: the source contains a local-SME exemption, linked to evidence of status.
- Missing or expired regulatory certificates have a committee-controlled remediation provision. Flag the gap and explain the provision; do not promise a cure or invent its deadline.
- The ERP special conditions use preference language. Company-level preferred experience is not the same as the mandatory proposed-team qualifications.
- Technical thresholds differ across superficially similar booklets. Store points and their denominator rather than treating a threshold as a percentage.
- The audit scoring table and award wording require clarification; preserve both rather than selecting a convenient interpretation.
- The dates are historical. Do not advertise the pilot opportunities as open today. Historical supplier evaluation uses an explicit scenario date.
- The booklet references the buyer's own procurement regulation. Legal applicability is not inferred from a generic Saudi procurement checklist.

Exact document/page/section mappings live in data/annotations/requirements.json; independently review before treating candidate assertions as gold.

## Business hypotheses and evidence required

| Hypothesis | How to validate | Current state |
| --- | --- | --- |
| Initial tender review is expensive | Measure active review and correction time on matched tasks | Not measured |
| Exceptions are often missed | Independent reviewer compares human/assisted findings | Not measured; examples exist in sources |
| Evidence chasing delays pursuit | Interview bid/compliance owners with a recent example | Not interviewed |
| Native CRM action saves re-entry | Observe current tools and compare approved task creation | Not measured |

No claim is made about annual tender volume, typical review duration, contracts won, or money saved.

## Interview guide (30–45 minutes)

Obtain permission before recording; use pseudonyms in notes. Do not contact anyone automatically.

1. Walk through a recent IT-services tender from discovery to pursuit decision. Which documents and systems did you use?
2. Who can decide pursuit, interpret an ambiguous clause, and approve an internal task?
3. Which requirements cause the most rework? Show one actual example, including exceptions and addenda.
4. Which evidence lives in CRM, shared files, HR, finance, or email? Who checks authenticity and expiry?
5. How do you learn that a booklet or deadline changed? How are old approvals invalidated?
6. Separate reading/extraction time from pricing, writing the technical response, and waiting on colleagues.
7. Which actions may be prepared automatically, and which require explicit approval?
8. Would the proposed matrix help? What would make it unusable? What is missing?

Interview register: zero interviews completed. Keep actual notes local; record role, date, consent, workflow observations, contradictory evidence and resulting scope changes. Do not present simulated personas as customer validation.

## Before Phase 1 sign-off

- Independently review candidate labels and add a complete mandatory-clause inventory for chosen benchmark tasks.
- Collect at least two more authorized relevant packs toward the planned 5–10-document corpus; include a different buyer/template family for a real holdout.
- Obtain practitioner feedback and at least one quality-reviewed manual timing trial. A paired impact claim must wait for the assisted workflow.
- Phase 0 external-model/calendar/testing-environment gates remain open. Phase 1 local work does not resolve them or authorize uploads.
