#!/usr/bin/env bash
# Calculate deadline status for all submission timeline milestones
# Writes data/deadline-status.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 - <<'PYTHON'
import json
import os
import sys
from datetime import date, datetime

project_root = os.environ.get("PROJECT_ROOT", os.getcwd())
timeline_path = os.path.join(project_root, "data", "submission-timeline.json")
output_path = os.path.join(project_root, "data", "deadline-status.json")

if not os.path.exists(timeline_path):
    print("ERROR: data/submission-timeline.json not found", file=sys.stderr)
    sys.exit(1)

with open(timeline_path) as f:
    timeline = json.load(f)

today = date.today()
submission_deadline = datetime.strptime(timeline["submission_deadline"], "%Y-%m-%d").date()
days_to_submission = (submission_deadline - today).days

milestone_statuses = []
overdue_count = 0
at_risk_count = 0

for milestone in timeline.get("milestones", []):
    target_date = datetime.strptime(milestone["target_date"], "%Y-%m-%d").date()
    days_remaining = (target_date - today).days
    status = milestone.get("status", "pending")

    if status == "completed":
        risk = "none"
    elif days_remaining < 0:
        risk = "overdue"
        overdue_count += 1
    elif days_remaining <= 21:
        risk = "at-risk"
        at_risk_count += 1
    elif days_remaining <= 60:
        risk = "monitor"
    else:
        risk = "on-track"

    milestone_statuses.append({
        "id": milestone["id"],
        "name": milestone["name"],
        "target_date": milestone["target_date"],
        "days_remaining": days_remaining,
        "status": status,
        "risk": risk
    })

# Calculate timeline adherence score (0-100)
# Based on how many milestones are on-track relative to their due dates
total_due = sum(1 for m in milestone_statuses if m["days_remaining"] <= 0 or m["status"] == "completed")
on_track = sum(1 for m in milestone_statuses if m["status"] == "completed" or m["risk"] in ("on-track", "monitor"))

if len(milestone_statuses) > 0:
    adherence_score = round((on_track / len(milestone_statuses)) * 100, 1)
else:
    adherence_score = 100.0

output = {
    "calculated_date": today.isoformat(),
    "days_to_submission": days_to_submission,
    "submission_deadline": timeline["submission_deadline"],
    "adherence_score": adherence_score,
    "overdue_count": overdue_count,
    "at_risk_count": at_risk_count,
    "milestones": milestone_statuses
}

os.makedirs(os.path.dirname(output_path), exist_ok=True)
with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"Deadline status calculated: {days_to_submission} days to submission")
print(f"Adherence score: {adherence_score}/100")
print(f"Overdue: {overdue_count} | At-risk: {at_risk_count}")
print(f"Written to: {output_path}")
PYTHON
