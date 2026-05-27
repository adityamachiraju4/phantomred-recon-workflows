#!/usr/bin/env bash
# =============================================================================
# nuclei-pipeline.sh — PhantomRed Nuclei Automation Pipeline
# =============================================================================
# Usage:   ./scripts/nuclei-pipeline.sh <live-hosts.txt> [output-dir]
# Example: ./scripts/nuclei-pipeline.sh output/target.com/latest/live-hosts.txt
#
# Stages:
#   1. Template update
#   2. Severity-gated Nuclei scan (exposures, CVEs, misconfigs, takeovers)
#   3. JSON triage + severity summary
#   4. Delta detection vs previous scan
#
# Requirements: nuclei, jq
# Install:  go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
# =============================================================================

set -euo pipefail

HOSTS="${1:-}"
if [[ -z "$HOSTS" || ! -f "$HOSTS" ]]; then
  echo "Usage: $0 <live-hosts.txt> [output-dir]"
  exit 1
fi

OUTDIR="${2:-./output/nuclei/$(date +%Y%m%d_%H%M%S)}"
PREV_SCAN="$(dirname "$OUTDIR")/latest-nuclei"
mkdir -p "$OUTDIR"

HOST_COUNT=$(wc -l < "$HOSTS")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PhantomRed — Nuclei Pipeline"
echo "  Hosts  : $HOST_COUNT"
echo "  Output : $OUTDIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# -----------------------------------------------------------------------------
# STAGE 1 — Update templates
# -----------------------------------------------------------------------------
echo ""
echo "[1/4] Updating Nuclei templates..."
nuclei -update-templates -silent 2>/dev/null || echo "    (template update skipped — offline?)"

# -----------------------------------------------------------------------------
# STAGE 2 — Nuclei scan (severity-gated, high-value categories)
# -----------------------------------------------------------------------------
echo ""
echo "[2/4] Running Nuclei scan..."
echo "    Templates : exposures/, cves/, misconfiguration/, takeovers/"
echo "    Severity  : medium, high, critical"
echo "    Rate limit: 50 req/sec"

nuclei \
  -l "$HOSTS" \
  -t exposures/,cves/,misconfiguration/,takeovers/ \
  -severity medium,high,critical \
  -rate-limit 50 \
  -bulk-size 25 \
  -timeout 10 \
  -retries 1 \
  -silent \
  -json \
  -o "$OUTDIR/nuclei-results.json" || true

FINDING_COUNT=$(wc -l < "$OUTDIR/nuclei-results.json" 2>/dev/null || echo 0)
echo "    Raw findings: $FINDING_COUNT"

# -----------------------------------------------------------------------------
# STAGE 3 — Triage: sort by severity, extract key fields
# -----------------------------------------------------------------------------
echo ""
echo "[3/4] Triage..."

if [[ -s "$OUTDIR/nuclei-results.json" ]]; then
  jq -r '[.info.severity, .host, .info.name, .matched_at] | @tsv' \
    "$OUTDIR/nuclei-results.json" \
    | sort -k1 \
    > "$OUTDIR/triage-sorted.txt"

  CRITICAL=$(grep -c '^critical' "$OUTDIR/triage-sorted.txt" 2>/dev/null || echo 0)
  HIGH=$(grep -c '^high'     "$OUTDIR/triage-sorted.txt" 2>/dev/null || echo 0)
  MEDIUM=$(grep -c '^medium'  "$OUTDIR/triage-sorted.txt" 2>/dev/null || echo 0)
else
  echo "    No findings — empty results file"
  CRITICAL=0; HIGH=0; MEDIUM=0
fi

# -----------------------------------------------------------------------------
# STAGE 4 — Delta vs previous scan
# -----------------------------------------------------------------------------
echo ""
echo "[4/4] Delta detection..."

if [[ -f "$PREV_SCAN/triage-sorted.txt" ]]; then
  comm -13 \
    <(sort "$PREV_SCAN/triage-sorted.txt") \
    <(sort "$OUTDIR/triage-sorted.txt") \
    > "$OUTDIR/new-findings.txt" 2>/dev/null || true
  NEW_COUNT=$(wc -l < "$OUTDIR/new-findings.txt")
  echo "    Net-new findings: $NEW_COUNT"
else
  echo "    No previous scan — skipping delta"
fi

rm -f "$PREV_SCAN"
ln -s "$OUTDIR" "$PREV_SCAN"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Nuclei scan complete"
echo "  Critical : $CRITICAL"
echo "  High     : $HIGH"
echo "  Medium   : $MEDIUM"
echo "  Results  : $OUTDIR/triage-sorted.txt"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
