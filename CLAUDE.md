# Accreditation Tracker — Agent Context

## What This Project Is

An automated accreditation evidence pipeline for Lakewood State University's HLC reaccreditation (submission deadline: March 1, 2027). The system manages the full evidence lifecycle: scraping current standards, inventorying existing documentation, performing gap analysis, coordinating remediation, and compiling the self-study report.

Three workflows run at different cadences: a one-time main pipeline, weekly readiness checks, and monthly progress reports.

## Data Model — What's in Each File

| File | What It Contains | Who Reads It | Who Writes It |
|---|---|---|---|
| `config/accreditor-profile.yaml` | Accrediting body, standards URL, evidence format requirements | standards-mapper, report-compiler | Never modified by agents |
| `config/institution-profile.yaml` | Institution details, departments, contacts, submission deadline | All agents | Never modified by agents |
| `data/requirements-matrix.json` | All standards, criteria, evidence requirements, responsible units | evidence-collector, gap-analyst, report-compiler | standards-mapper, map-requirements phase |
| `data/evidence-inventory.json` | All evidence items with status: collected/outdated/incomplete/missing | gap-analyst, report-compiler, readiness-reviewer | evidence-collector |
| `data/gap-analysis.json` | Gap classification, readiness verdict, reasoning | remediation-planner, report-compiler, readiness-reviewer | gap-analyst |
| `data/remediation-plan.json` | Assigned remediation actions with deadlines, effort, status | readiness-reviewer, report-compiler | remediation-planner |
| `data/submission-timeline.json` | Milestone targets and current status | readiness-reviewer, calculate-deadline-status.sh | Manual updates + readiness-reviewer |
| `data/deadline-status.json` | Current milestone risk levels and days remaining | readiness-reviewer | calculate-deadline-status.sh |
| `data/monthly-metrics.json` | Monthly aggregated metrics for all dimensions | generate-monthly-report phase | calculate-monthly-metrics.sh |
| `data/history/` | Monthly metric snapshots for trend analysis | readiness-reviewer | calculate-monthly-metrics.sh |
| `evidence/` | Collected evidence documents (organized by standard/criterion) | evidence-collector, report-compiler | Departments + evidence-collector |
| `evidence/requests/` | Collection request documents for missing evidence | Departments | evidence-collector |
| `evidence/pending/` | Placeholders for evidence in collection | evidence-collector | evidence-collector |
| `reports/self-study/` | Compiled self-study chapters (00-executive-summary, chapter-N-*) | report-compiler (reads for context) | report-compiler |
| `reports/remediation-actions.md` | Human-readable remediation tracker | Institutional staff | remediation-planner |
| `reports/readiness-dashboard-*.md` | Weekly leadership dashboards | Leadership | readiness-reviewer |
| `reports/monthly-progress-*.md` | Monthly progress reports | Leadership | readiness-reviewer |

## Domain Terminology

**HLC** — Higher Learning Commission. Regional accreditor for ~1,000 colleges and universities in the north-central US. Accreditation is required for federal Title IV financial aid.

**Criteria for Accreditation** — HLC's five main standards: Mission (1), Integrity (2), Teaching and Learning Quality (3), Teaching and Learning Evaluation (4), Resources and Effectiveness (5). Each has multiple core components.

**Core Component** — A specific criterion within a standard. HLC has ~25 core components. Missing evidence for a core component is a serious deficiency.

**Self-Study Report** — The institution's formal submission. 100-300 pages of narrative responses to each criterion, with evidence citations. Due 6-8 weeks before the site visit.

**Site Visit** — 3-4 day peer review visit by HLC-trained evaluators. They verify the self-study claims and interview faculty, staff, and students.

**Evidence Recency** — HLC typically requires evidence from the last 3-5 years. Older documents can be cited as historical context but must be paired with current evidence.

**Adverse Action** — Possible HLC outcomes: Continued Accreditation (pass), Monitoring (minor concerns), Probation (significant concerns), or Show Cause (risk of loss). This pipeline aims for Continued Accreditation with no monitoring.

## Workflow Invariants Agents Must Respect

1. **Evidence citation discipline**: Report-compiler must cite only evidence that exists in `evidence/` (by filename). Uncited claims are disqualifying in accreditation reports.

2. **Status transitions**: Evidence items can only move forward: missing → requested → pending → collected. Never move backward without explicit human instruction.

3. **Deadline awareness**: All remediation actions must have deadlines before the `evidence_collection_deadline` in config/institution-profile.yaml (2026-08-01). Report-compiler must schedule items before `self_study_draft_due` (2026-10-01).

4. **Critical gap priority**: When critical gaps are found, escalate-critical-gaps ALWAYS runs before plan-remediation. The escalation briefing must reach provost-level before remediation assignments are issued.

5. **Provost gate is real**: The `provost-approval` phase is a manual gate. Agents must not attempt to auto-advance past it. The self-study cannot be finalized without human sign-off.

6. **Board actions need extra lead time**: Any remediation item requiring board approval (mission statement revisions, policy changes) must have deadlines ≥90 days before the submission deadline.

7. **No fabricated evidence**: Evidence-collector must not create placeholder evidence documents that appear to be real institutional records. `pending/` placeholders are clearly marked as placeholders.

## Workflow Entry Points

| Workflow | When to Run | Starting Point |
|---|---|---|
| `accreditation-pipeline` | Once per accreditation cycle | `ao workflow run accreditation-pipeline` |
| `weekly-readiness-check` | Every Monday 8am | Auto via cron (`ao daemon start`) |
| `monthly-progress-report` | 1st of each month 9am | Auto via cron |

## Script Assumptions

The bash scripts embed Python3 calculation logic. They expect:
- Python 3.8+ with standard library (no external packages required)
- JSON data files in `data/` (scripts handle missing files gracefully with defaults)
- Working directory is `examples/accreditation-tracker/` (all paths are relative)

## Evidence Organization Convention

Evidence files should be organized as:
```
evidence/
  standard-1/          # By standard number
    criterion-1a/      # By criterion ID
      mission-statement-2024.pdf
      board-resolution-2024-01-15.pdf
  standard-3/
    criterion-3b/
      course-catalog-2024-2025.pdf
```

This structure allows evidence-collector to locate documents by standard/criterion mapping.
