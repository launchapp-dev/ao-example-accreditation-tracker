#!/usr/bin/env bash
# Package the self-study report and evidence for final submission
# Creates a timestamped submission archive and final submission manifest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 - <<'PYTHON'
import json
import os
import glob
import shutil
from datetime import date

project_root = os.environ.get("PROJECT_ROOT", os.getcwd())
today = date.today()
timestamp = today.strftime("%Y%m%d")

reports_dir = os.path.join(project_root, "reports")
evidence_dir = os.path.join(project_root, "evidence")
data_dir = os.path.join(project_root, "data")
submission_dir = os.path.join(project_root, f"submission-{timestamp}")

# Create submission directory
os.makedirs(submission_dir, exist_ok=True)
os.makedirs(os.path.join(submission_dir, "self-study"), exist_ok=True)
os.makedirs(os.path.join(submission_dir, "evidence"), exist_ok=True)

# Copy self-study report chapters
self_study_src = os.path.join(reports_dir, "self-study")
if os.path.exists(self_study_src):
    for f in glob.glob(os.path.join(self_study_src, "*.md")):
        shutil.copy2(f, os.path.join(submission_dir, "self-study"))
    print(f"Copied self-study chapters to submission package")

# Copy evidence files (exclude pending/ directory)
if os.path.exists(evidence_dir):
    for root, dirs, files in os.walk(evidence_dir):
        # Skip pending directory
        dirs[:] = [d for d in dirs if d != "pending"]
        for file in files:
            src_path = os.path.join(root, file)
            rel_path = os.path.relpath(src_path, evidence_dir)
            dst_path = os.path.join(submission_dir, "evidence", rel_path)
            os.makedirs(os.path.dirname(dst_path), exist_ok=True)
            shutil.copy2(src_path, dst_path)
    print(f"Copied evidence files to submission package")

# Generate submission manifest
evidence_inv_path = os.path.join(data_dir, "evidence-inventory.json")
evidence_inv = {}
if os.path.exists(evidence_inv_path):
    with open(evidence_inv_path) as f:
        evidence_inv = json.load(f)

gap_analysis_path = os.path.join(data_dir, "gap-analysis.json")
gap_analysis = {}
if os.path.exists(gap_analysis_path):
    with open(gap_analysis_path) as f:
        gap_analysis = json.load(f)

manifest = {
    "submission_date": today.isoformat(),
    "institution": "Lakewood State University",
    "accreditor": "Higher Learning Commission",
    "package_directory": f"submission-{timestamp}",
    "evidence_completion_pct": evidence_inv.get("overall_completion_pct", 0),
    "final_gap_verdict": gap_analysis.get("verdict", "unknown"),
    "self_study_chapters": len(glob.glob(os.path.join(submission_dir, "self-study", "chapter-*.md"))),
    "evidence_documents": sum(
        len(files) for _, _, files in os.walk(os.path.join(submission_dir, "evidence"))
    ),
    "status": "packaged_pending_upload"
}

manifest_path = os.path.join(submission_dir, "submission-manifest.json")
with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)

print(f"\nSubmission package created: submission-{timestamp}/")
print(f"Self-study chapters: {manifest['self_study_chapters']}")
print(f"Evidence documents: {manifest['evidence_documents']}")
print(f"Manifest written to: {manifest_path}")
print(f"\nNext step: Upload to {open(os.path.join(project_root, 'config/accreditor-profile.yaml')).read().split('submission_portal:')[1].split()[0] if os.path.exists(os.path.join(project_root, 'config/accreditor-profile.yaml')) else 'accreditor portal'}")
PYTHON
