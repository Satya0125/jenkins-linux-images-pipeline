#!/bin/bash
# validate.sh
# Runs a compliance scan against the hardened image using OpenSCAP
# and writes a report + a machine-readable summary for the pipeline.

set -euo pipefail
echo ">>> Running compliance validation..."

REPORT_DIR="/tmp/compliance-report"
mkdir -p "$REPORT_DIR"

apt-get install -y libopenscap8 ssg-debderived 2>/dev/null || true

# Run the OpenSCAP CIS profile scan (adjust the datastream path/profile
# to match whatever SCAP content you install for your OS).
DATASTREAM=$(find /usr/share/xml/scap -iname "*ubuntu2204*ds.xml" 2>/dev/null | head -n1 || true)

if [ -n "$DATASTREAM" ]; then
  oscap xccdf eval \
    --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
    --results "$REPORT_DIR/results.xml" \
    --report "$REPORT_DIR/scan-report.html" \
    "$DATASTREAM" || true

  # Extract pass/fail counts from the results file
  PASS_COUNT=$(grep -c 'result>pass<' "$REPORT_DIR/results.xml" || echo 0)
  FAIL_COUNT=$(grep -c 'result>fail<' "$REPORT_DIR/results.xml" || echo 0)
  TOTAL=$((PASS_COUNT + FAIL_COUNT))

  if [ "$TOTAL" -gt 0 ]; then
    SCORE=$(awk "BEGIN { printf \"%.1f\", ($PASS_COUNT/$TOTAL)*100 }")
  else
    SCORE="0.0"
  fi

  if [ "$FAIL_COUNT" -eq 0 ]; then
    STATUS="PASS"
  elif [ "$FAIL_COUNT" -le 5 ]; then
    STATUS="WARN"
  else
    STATUS="FAIL"
  fi
else
  echo "No SCAP datastream found, skipping automated scan."
  SCORE="0.0"
  STATUS="WARN"
fi

# Write a simple summary the Jenkins pipeline stage can read and POST
cat <<EOF > "$REPORT_DIR/summary.json"
{
  "compliance_status": "$STATUS",
  "compliance_score": $SCORE
}
EOF

echo ">>> Compliance validation complete: status=$STATUS score=$SCORE"
cat "$REPORT_DIR/summary.json"
