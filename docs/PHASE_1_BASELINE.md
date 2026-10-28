# Manual baseline and comparison protocol

Status: protocol implemented; zero real trials. Do not invent a timing baseline from an AI reading session or use earlier 2–3-week estimates.

## Task

Given an authorized tender pack and the same supplier evidence, produce a pursuit-review sheet with critical dates, scoped mandatory requirements, exceptions, gaps and source pages. Stop before pricing, external submission or legal certification. Use the same reviewed assertion scope and completion criteria in both conditions.

Manual condition: original PDF, ordinary document viewer and blank review sheet; no AI. Assisted condition: the future review cockpit plus original PDF. Include loading, evidence verification, edits and correction time; log breaks and waiting separately. Do not count only model-generation latency.

Use pseudonymous participants. Record order; counterbalance conditions across participants/document assignments and acknowledge learning effects when a document is repeated. An independent reviewer, not the timed participant, scores missed critical findings, false mandatory claims and citation errors against adjudicated scope. A faster incomplete review is not a successful result.

## Capture

Use data/baseline/trials.csv (header only initially). Each row records trial_id, pair_id, participant_id, document_id, manual/assisted mode, order, active_seconds, reviewed_assertions, missed_critical, false_mandatory, citation_errors, quality_reviewed_by and completed. A pair requires the same participant, document and scope. Store original notes/screenshots locally under data/runs/; do not commit identifiable customer data.

Start a stopwatch when the task begins; stop after verification and final edits. Do not create artificial rows merely to fill the CSV. Record a complete=false trial if processing fails; failure rates must be reported separately rather than dropping failed tasks from an impact study.

## Report

scripts/summarize_baseline.py includes only completed, independently quality-reviewed pairs with equal review scope. It emits not_measured and null savings when no valid pairs exist. It reports median paired reduction, range and error totals; negative savings are retained. Incomplete/unreviewed trials are not evidence of savings. Publish trial inclusion/exclusion counts with any later report.

Formula per pair: 100 × (manual active seconds − assisted active seconds) / manual active seconds. Report sample size, quality and correction effort alongside time. Do not extrapolate to revenue, tender wins or avoided legal losses.
