# Pilot dataset and annotation rubric

Version: phase1-pilot-v1.1. Source acquisition: user downloaded three Taqeem booklets through their browser on October 28, 2026 after automated access returned 403. The user supplied files for this project; originals and extracted text remain local. Do not retry bypass techniques or replace unavailable government packs with a different buyer cohort without discussing it.

## Corpus

| Stable source ID | Original file | Pages | Issued |
| --- | --- | --- | --- |
| TAQEEM-SOFTWARE-2026 | bid_attachment.pdf | 61 | 2026-03-12 |
| TAQEEM-ERP-2026 | bid_attachment (1).pdf | 36 | 2026-02-15 |
| TAQEEM-AUDIT-2026 | bid_attachment (2).pdf | 37 | 2026-02-24 |

Manifest: data/sources/government_manifest.json contains SHA-256, source URL, reference, local acquisition path and template group. All three are development data because they share one buyer/template and have been inspected during authoring. No blind held-out performance can be claimed. The ERP booklet is marked Internal; redistribution is not authorized. At acquisition cloud-upload permission was not established. The user's subsequent explicit authorization for these three PDFs is recorded separately in data/sources/cloud_authorizations.json. They were then tested through Vertex; see docs/VERTEX_PDF_RESULTS.md. No documents have been uploaded to Salesforce.

Revision v1.1 corrects TAQEEM-AUDIT-2026::BID_SECURITY_RATE to page 16 after inspecting the original rendered page. The previous page 15 reference pointed to the heading rather than the numeric clause. This remains agent-reviewed candidate data, not independent gold.

Earlier ENSAN downloads are retained in ignored local storage as supplemental discovery artifacts only. They are not part of the primary corpus or scored benchmark. No more alternate-source acquisition is scheduled. scripts/acquire_sources.py is an earlier optional acquisition utility, not a required phase command.

## What the labels mean

- 62 candidate assertions cover selected clauses, not all 134 pages or all mandatory requirements. All require independent domain review.
- 12 real-source queries cover Arabic, English and mixed-language questions over Arabic sources.
- Five original synthetic regression fixtures exercise exceptions, addenda, untrusted document instructions, scoring units, ambiguous calendars and misleading numeric matches. These include Arabic and English source text. Synthetic fixtures are not customer evidence.
- The synthetic supplier profile is deliberately incomplete. Claimed SME status is unverified; absent evidence is unknown, not proof of noncompliance. No real company credentials are included.
- Page numbers are one-based PDF pages, independently stored from printed labels. Section IDs identify the relevant clauses. Exact text offsets are not asserted by these page-level candidate labels.

## Annotation procedure

1. Confirm source identity/hash and record the version. Inspect the rendered page, not only extracted text.
2. Label the unit of meaning: an obligation, a date, a preference, an exception, an evaluation rule, or a clarification. Split separate certificate requirements and preserve their applicability conditions.
3. Distinguish bidder qualification, proposed-team requirements, submission requirements, scored criteria and post-award obligations. Do not promote every imperative to a participation gate.
4. Search the rest of the booklet and attachments for exceptions, cure periods, special conditions and precedence. Link clauses; a lone quotation is insufficient.
5. Record normalized value/unit/basis and preserve uncertainty. Do not invent percentages, a noon/midnight interpretation, timezone, award date or calendar conversion.
6. Keep document language separate from query/response language. Translated explanations must cite the Arabic original.
7. For omissions or uncertain scope, mark unknown or needs_clarification. Record contradictory evidence and a reviewer rationale.
8. A second reviewer checks labels without seeing model predictions; resolve disagreements and record reviewer/version/date before promotion to gold. Preserve the previous annotation version.

Candidate statuses: agent_candidate_not_independent_gold → independently_reviewed → adjudicated. The current validator deliberately rejects untracked status promotion; review workflow and validation rules must be updated together when actual reviews occur.

## Evaluation contract

Do not report whole-document extraction recall from this selected-clause set. First define a fully annotated evaluation scope and explicitly state the denominator. For the initial pilot, report candidate-assertion recovery only, separately from unseen false-positive requirements.

Measure category/applicability correctness, exact numeric/date values, exception linkage, citation support, appropriate abstention, multilingual retrieval and unauthorized side effects. String presence is only a supporting evidence check, not semantic faithfulness. Distinguish missing records from missing evidence and from an inaccessible field.

No real addendum, scan-only government pack, long BOQ table benchmark, independent gold set or supplier evidence has been acquired. Synthetic tests cover mechanisms but cannot fill those empirical gaps.

## Reproduce locally

Use the Codex bundled Python runtime (pypdf and pypdfium2 are available there) for source import and rendering. The validation, baseline and unittest commands use only the Python standard library and can use ordinary python.

```powershell
# Only when the user-supplied PDFs are present; requires pypdf:
python scripts/import_local_tenders.py
# Public metadata integrity; no source PDFs required:
python scripts/validate_dataset.py
# Also verify local PDF bytes and full page ledgers:
python scripts/validate_dataset.py --check-local
python -m unittest discover -s tests -v
# Empty trials correctly produce not_measured:
python scripts/summarize_baseline.py
```

Checks validate dataset structure/provenance, not correctness of the domain interpretation. The extraction here is a local reading aid; the planned production parsing baseline remains direct VLM document understanding.
