# Accreditation Evidence Pipeline

An AI-powered accreditation management system that maps institutional standards to evidence requirements, inventories and collects documentation from departments, performs gap analysis, generates remediation plans, compiles the self-study report, and produces weekly readiness dashboards for institutional leadership — running fully automated.

---

## How It Works

Three workflows cover the full accreditation lifecycle:

```
PIPELINE (run once per accreditation cycle)
  scrape-standards ──► map-requirements ──► inventory-evidence ──► assess-evidence-completeness
                                                                           │
                                                        [sufficient] ──►──┤
                                                     [needs-more] ──►── collect-additional-evidence
                                                       [missing]  ──►── collect-additional-evidence
                                                                           │
                                                                      analyze-gaps
                                                                           │
                                         [ready] ──────────────────────►──┤
                                      [gaps-found] ──► plan-remediation ──►┤
                                   [critical-gaps] ──► escalate-critical-gaps ──► plan-remediation
                                                                           │
                                                                    compile-self-study
                                                                           │
                                                                   provost-approval (MANUAL)
                                                                           │
                                                                  finalize-submission

WEEKLY (Monday 8am)
  calculate-deadline-status ──► update-readiness-dashboard

MONTHLY (1st of month 9am)
  calculate-monthly-metrics ──► generate-monthly-report
```

---

## Agents

| Agent | Model | Role |
|---|---|---|
| **standards-mapper** | claude-sonnet-4-6 | Scrapes accreditor website, maps each criterion to required evidence and responsible unit |
| **evidence-collector** | claude-sonnet-4-6 | Inventories existing documentation, assesses completeness, coordinates collection requests |
| **gap-analyst** | claude-opus-4-6 | Classifies gaps by severity, traces multi-criterion dependencies, issues readiness verdict |
| **remediation-planner** | claude-sonnet-4-6 | Creates assigned, time-bound remediation actions for each identified gap |
| **report-compiler** | claude-opus-4-6 | Drafts narrative responses to each criterion, compiles self-study report with evidence citations |
| **readiness-reviewer** | claude-haiku-4-5 | Calculates weekly composite readiness score, flags overdue/at-risk items, produces leadership dashboard |

---

## AO Features Demonstrated

| Feature | Where |
|---|---|
| **Playwright MCP for web scraping** | `scrape-standards` phase — extracts current standards from accreditor's website |
| **Decision contracts** | `assess-evidence-completeness` (sufficient/needs-more/missing), `analyze-gaps` (ready/gaps-found/critical-gaps) |
| **Phase routing** | Evidence verdict routes to gap analysis or evidence collection; readiness verdict routes to remediation or escalation |
| **Manual approval gate** | `provost-approval` phase — provost must sign off before submission package is finalized |
| **Escalation path** | `critical-gaps` verdict triggers `escalate-critical-gaps` with leadership briefing before remediation planning |
| **Output contracts** | Structured JSON on evidence assessment, gap analysis, report compilation |
| **Scheduled workflows** | Weekly readiness dashboard (Mon 8am), monthly progress report (1st of month 9am) |
| **Command phases** | 3 bash scripts with embedded Python for deadline and metrics calculation |
| **Multi-model pipeline** | Opus for complex analysis and report compilation, Sonnet for structured collection/planning, Haiku for fast dashboard generation |
| **Rework loops** | `analyze-gaps` can loop up to 3 times as evidence collection improves |

---

## Quick Start

### Prerequisites
- Node.js 18+ (for MCP servers via npx)
- Python 3.8+ (for metric calculation scripts)
- AO daemon installed and configured

### Setup

1. Update `config/accreditor-profile.yaml` with your accrediting body and standards URL
2. Update `config/institution-profile.yaml` with your institution's details, department contacts, and submission deadline

### Run the pipeline

```bash
cd examples/accreditation-tracker

# Run the full accreditation pipeline (one-time per cycle)
ao workflow run accreditation-pipeline

# Start the daemon for automated weekly/monthly reporting
ao daemon start --autonomous

# Watch live logs
ao daemon stream --pretty
```

### Monitor progress

```bash
# Check current readiness status
ao status --project-root examples/accreditation-tracker/

# Run a manual readiness check
ao workflow run weekly-readiness-check

# View errors
ao errors list --project-root examples/accreditation-tracker/
```

---

## Requirements

### API Keys
None required — this pipeline uses Claude models via the AO daemon. No external API keys needed.

### MCP Servers (auto-installed via npx)
- `@modelcontextprotocol/server-filesystem` — read/write all evidence files and reports
- `@modelcontextprotocol/server-sequential-thinking` — structured reasoning for gap analysis and report compilation
- `@playwright/mcp` — browser automation for scraping accreditor standards documentation

### Runtime
- Node.js 18+ (for MCP servers via npx)
- Python 3.8+ (for metric calculation scripts, standard library only)

---

## Project Layout

```
examples/accreditation-tracker/
├── .ao/workflows/
│   ├── agents.yaml               # 6 agent profiles
│   ├── phases.yaml               # 15 phase definitions
│   ├── workflows.yaml            # 3 workflow pipelines
│   ├── mcp-servers.yaml          # filesystem + sequential-thinking + playwright
│   └── schedules.yaml            # 2 cron schedules
├── config/
│   ├── accreditor-profile.yaml   # Which accreditor, standards URL, format requirements
│   └── institution-profile.yaml  # Institution details, departments, submission deadline
├── scripts/
│   ├── calculate-deadline-status.sh    # Milestone deadline status
│   ├── calculate-monthly-metrics.sh    # Monthly progress aggregation
│   └── package-submission.sh           # Package final submission archive
├── data/
│   ├── requirements-matrix.json   # Scraped + mapped standards (populated by pipeline)
│   ├── evidence-inventory.json    # Evidence collection status (populated by pipeline)
│   ├── gap-analysis.json          # Gap analysis results (populated by pipeline)
│   ├── remediation-plan.json      # Remediation action plan (populated by pipeline)
│   ├── submission-timeline.json   # Milestones and deadlines
│   ├── deadline-status.json       # Current milestone status (populated by scripts)
│   ├── monthly-metrics.json       # Current month aggregates (populated by scripts)
│   └── history/                   # Monthly snapshots for trend analysis
├── evidence/                      # Collected evidence documents (organized by standard)
│   ├── requests/                  # Evidence collection requests generated by pipeline
│   └── pending/                   # Placeholders for evidence being collected
├── reports/
│   ├── self-study/                # Compiled self-study report chapters
│   ├── remediation-actions.md     # Human-readable remediation action tracker
│   ├── standards-map.md           # Human-readable standards mapping
│   ├── readiness-dashboard-*.md   # Weekly dashboard reports
│   └── monthly-progress-*.md      # Monthly progress reports
└── .env.example
```

---

## Workflow Details

### accreditation-pipeline (run once per cycle)

The main pipeline handles the full evidence lifecycle:

1. **scrape-standards** — Playwright scrapes the accreditor's website to extract all standards, criteria, and evidence requirements
2. **map-requirements** — Maps each criterion to responsible institutional units and sets deadline targets
3. **inventory-evidence** — Scans the `evidence/` directory against requirements; records what's collected, outdated, incomplete, or missing
4. **assess-evidence-completeness** — Decision: `sufficient` (≥90%) → gap analysis; `needs-more` or `missing` → collection phase
5. **collect-additional-evidence** — Generates collection request documents for missing items; marks evidence as requested
6. **analyze-gaps** — Classifies gaps by severity; issues verdict: `ready`, `gaps-found`, or `critical-gaps`
7. **plan-remediation** — Creates assigned, time-bound remediation actions (entered when gaps-found)
8. **escalate-critical-gaps** — Drafts leadership briefing, escalation log (entered when critical-gaps)
9. **compile-self-study** — Drafts criterion-by-criterion narrative responses with evidence citations
10. **provost-approval** — **Manual gate**: provost reviews and approves the report before finalization
11. **finalize-submission** — Packages self-study and evidence into timestamped submission archive

### weekly-readiness-check (every Monday 8am)

Calculates a composite readiness score (0-100) across four dimensions:
- Evidence completion (40%)
- Remediation progress (30%)
- Timeline adherence (20%)
- Report readiness (10%)

Produces a markdown dashboard in `reports/` flagging overdue, at-risk, and stalled items.

### monthly-progress-report (1st of each month 9am)

Aggregates month-over-month trends across all metrics and generates a leadership report covering:
- Evidence collection progress by standard
- Remediation tracker (completed, in-progress, overdue)
- Timeline health and composite readiness trend (ASCII chart)
- Next month priorities and leadership actions required

---

## Domain Context

**Accreditation** — A formal peer-review process in which an external accrediting body evaluates whether an institution meets established standards of educational quality. Regional accreditation (HLC, SACSCOC, etc.) is required for Title IV federal financial aid eligibility.

**Self-Study Report** — The institution's primary submission document. It presents narrative responses to each accreditation criterion, supported by evidence. Typically 100-300 pages.

**Evidence Matrix** — The systematic mapping of accreditation criteria to supporting documentation. Without a complete evidence matrix, writing the self-study is impossible.

**Gap Analysis** — Systematic comparison of required evidence vs. available evidence. Critical gaps in core criteria can result in adverse accreditation action (monitoring, probation, or loss of accreditation).

**Site Visit** — After reviewing the self-study, the accreditor sends a peer review team to visit the institution. The visit validates the self-study's claims. Institutions must be prepared to produce any cited evidence on demand.

---

## Sample Output

### Weekly Readiness Dashboard (`reports/readiness-dashboard-2026-06-02.md` excerpt)
```
# Accreditation Readiness Dashboard — June 2, 2026
## Composite Readiness Score: 71/100 — AT-RISK

| Dimension               | Score | Weight | Weighted |
|-------------------------|-------|--------|---------|
| Evidence Completion     | 68%   | 40%    | 27.2    |
| Remediation Progress    | 45%   | 30%    | 13.5    |
| Timeline Adherence      | 90%   | 20%    | 18.0    |
| Report Readiness        | 20%   | 10%    | 2.0     |
| **Composite**           |       |        | **60.7**|

## Items Overdue (2)
- Standard 3 — Assessment Policy update (Academic Affairs) — 14 days overdue
- Standard 4 — Program Review data (IE Office) — 3 days overdue

## Items At-Risk (4)
- Standard 1 — Mission statement revision (Board approval needed) — 18 days
...
```

### Gap Analysis (`data/gap-analysis.json` excerpt)
```json
{
  "verdict": "gaps-found",
  "overall_completion_pct": 76.3,
  "critical_gaps": [],
  "significant_gaps": [
    {
      "standard_id": "4",
      "criterion_id": "4.B",
      "gap_description": "No institution-wide assessment results report for last 3 years"
    }
  ]
}
```
