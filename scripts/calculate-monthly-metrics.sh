#!/usr/bin/env bash
# Aggregate monthly accreditation progress metrics
# Reads evidence-inventory, remediation-plan, gap-analysis, deadline-status
# Writes data/monthly-metrics.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 - <<'PYTHON'
import json
import os
import glob
from datetime import date, datetime

project_root = os.environ.get("PROJECT_ROOT", os.getcwd())
data_dir = os.path.join(project_root, "data")
reports_dir = os.path.join(project_root, "reports")
history_dir = os.path.join(data_dir, "history")
output_path = os.path.join(data_dir, "monthly-metrics.json")

today = date.today()
month_label = today.strftime("%Y-%m")

def load_json(path, default=None):
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return default or {}

# Load current data files
evidence_inv = load_json(os.path.join(data_dir, "evidence-inventory.json"))
remediation = load_json(os.path.join(data_dir, "remediation-plan.json"))
gap_analysis = load_json(os.path.join(data_dir, "gap-analysis.json"))
deadline_status = load_json(os.path.join(data_dir, "deadline-status.json"))
timeline = load_json(os.path.join(data_dir, "submission-timeline.json"))

# Evidence metrics
evidence_pct = evidence_inv.get("overall_completion_pct", 0.0)
evidence_verdict = evidence_inv.get("verdict", "unknown")
evidence_items = evidence_inv.get("items", [])
collected_count = sum(1 for i in evidence_items if i.get("status") == "collected")
total_count = len(evidence_items)

# Remediation metrics
remediation_items = remediation.get("remediation_items", [])
total_remed = len(remediation_items)
completed_remed = sum(1 for i in remediation_items if i.get("status") == "completed")
in_progress_remed = sum(1 for i in remediation_items if i.get("status") == "in-progress")
overdue_remed = sum(
    1 for i in remediation_items
    if i.get("status") not in ("completed",) and i.get("deadline")
    and datetime.strptime(i["deadline"], "%Y-%m-%d").date() < today
)
remediation_pct = round((completed_remed / total_remed * 100), 1) if total_remed > 0 else 0.0

# Gap metrics
critical_gaps = len(gap_analysis.get("critical_gaps", []))
significant_gaps = len(gap_analysis.get("significant_gaps", []))
minor_gaps = len(gap_analysis.get("minor_gaps", []))
gap_verdict = gap_analysis.get("verdict", "unknown")

# Self-study report progress
self_study_dir = os.path.join(reports_dir, "self-study")
chapter_files = glob.glob(os.path.join(self_study_dir, "chapter-*.md")) if os.path.exists(self_study_dir) else []
chapters_compiled = len(chapter_files)

# Compute total standards count from gap analysis structure (best proxy)
standards_total = len(evidence_inv.get("items", []))  # rough proxy
chapters_pct = 0.0  # needs standards total to compute meaningfully

# Timeline adherence
adherence_score = deadline_status.get("adherence_score", 0.0)
days_to_submission = deadline_status.get("days_to_submission", 365)

# Load prior month metrics for trend
prior_month_path = os.path.join(history_dir, f"metrics-{today.replace(day=1).strftime('%Y-%m')}.json")
prior_metrics = load_json(prior_month_path, {})
prior_evidence_pct = prior_metrics.get("evidence_pct", 0.0)
prior_remediation_pct = prior_metrics.get("remediation_pct", 0.0)

output = {
    "month": month_label,
    "calculated_date": today.isoformat(),
    "days_to_submission": days_to_submission,
    "evidence": {
        "completion_pct": evidence_pct,
        "verdict": evidence_verdict,
        "items_collected": collected_count,
        "items_total": total_count,
        "pct_change_vs_prior_month": round(evidence_pct - prior_evidence_pct, 1)
    },
    "remediation": {
        "completion_pct": remediation_pct,
        "items_total": total_remed,
        "items_completed": completed_remed,
        "items_in_progress": in_progress_remed,
        "items_overdue": overdue_remed,
        "pct_change_vs_prior_month": round(remediation_pct - prior_remediation_pct, 1)
    },
    "gaps": {
        "verdict": gap_verdict,
        "critical": critical_gaps,
        "significant": significant_gaps,
        "minor": minor_gaps,
        "total": critical_gaps + significant_gaps + minor_gaps
    },
    "report": {
        "chapters_compiled": chapters_compiled
    },
    "timeline": {
        "adherence_score": adherence_score,
        "overdue_milestones": deadline_status.get("overdue_count", 0),
        "at_risk_milestones": deadline_status.get("at_risk_count", 0)
    }
}

os.makedirs(data_dir, exist_ok=True)
with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

# Archive snapshot to history
os.makedirs(history_dir, exist_ok=True)
archive_path = os.path.join(history_dir, f"metrics-{month_label}.json")
with open(archive_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"Monthly metrics calculated for {month_label}")
print(f"Evidence: {evidence_pct:.1f}% | Remediation: {remediation_pct:.1f}%")
print(f"Days to submission: {days_to_submission}")
print(f"Written to: {output_path}")
PYTHON
