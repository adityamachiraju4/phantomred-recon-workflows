#!/usr/bin/env bash
# =============================================================================
# full-recon-pipeline.sh — PhantomRed Full Autonomous Recon Pipeline
# =============================================================================
# Usage:   ./scripts/full-recon-pipeline.sh <target.com>
# Example: ./scripts/full-recon-pipeline.sh hackerone.com
#
# Full pipeline:
#   1. Passive subdomain enumeration  (subfinder + assetfinder + amass)
#   2. DNS validation + CNAME check   (dnsx)
#   3. Live host probing              (httpx)
#   4. Nuclei vulnerability scan      (exposures, CVEs, misconfigs, takeovers)
#   5. FFUF content discovery         (directory + backup fuzzing)
#   6. Triage summary + delta report
#
# Requirements: subfinder, assetfinder, amass, dnsx, httpx, nuclei, ffuf, jq
# =============================================================================

set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target.com>"
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUT="./output/${TARGET}/${TIMESTAMP}"
mkdir -p "$OUT"

START_TIME=$SECONDS

echo ""
echo "┌─────────────────────────────────────────────┐"
echo "│   PhantomRed — Full Recon Pipeline          │"
echo "│   Target : $TARGET"
echo "│   Output : $OUT"
echo "└─────────────────────────────────────────────┘"
echo ""

# =============================================================================
# PHASE 1 — SUBDOMAIN ENUMERATION
# =============================================================================
echo "▶ Phase 1: Subdomain Enumeration"
echo "─────────────────────────────────"

echo "  [1a] Passive enumeration (parallel)..."
subfinder  -d "$TARGET" -silent -all -o "$OUT/sf.txt"       2>/dev/null &
assetfinder --subs-only "$TARGET" > "$OUT/af.txt"           2>/dev/null &
amass enum -passive -d "$TARGET"  -o "$OUT/am.txt"          2>/dev/null &
wait

cat "$OUT/sf.txt" "$OUT/af.txt" "$OUT/am.txt" 2>/dev/null \
  | sort -u > "$OUT/subs-all.txt"
SUBS=$(wc -l < "$OUT/subs-all.txt")
echo "  Unique subdomains : $SUBS"

# =============================================================================
# PHASE 2 — DNS VALIDATION
# =============================================================================
echo ""
echo "▶ Phase 2: DNS Validation"
echo "─────────────────────────"

echo "  [2a] Resolving DNS records..."
dnsx -l "$OUT/subs-all.txt" -silent -o "$OUT/dns-valid.txt"
DNS=$(wc -l < "$OUT/dns-valid.txt")
echo "  DNS-valid         : $DNS"

echo "  [2b] CNAME takeover check..."
dnsx -l "$OUT/subs-all.txt" -cname -silent \
  | grep -E 'amazonaws|github\.io|heroku|azurewebsites|shopify|fastly|netlify' \
  > "$OUT/potential-takeovers.txt" 2>/dev/null || true
TAKEOVERS=$(wc -l < "$OUT/potential-takeovers.txt")
echo "  Potential takeovers: $TAKEOVERS"

# =============================================================================
# PHASE 3 — LIVE HOST PROBING
# =============================================================================
echo ""
echo "▶ Phase 3: Live Host Probing"
echo "─────────────────────────────"

httpx \
  -l "$OUT/dns-valid.txt" \
  -silent \
  -threads 50 \
  -timeout 10 \
  -tech-detect \
  -status-code \
  -o "$OUT/live-hosts.txt"
LIVE=$(wc -l < "$OUT/live-hosts.txt")
echo "  Live hosts        : $LIVE"

# =============================================================================
# PHASE 4 — NUCLEI VULNERABILITY SCAN
# =============================================================================
echo ""
echo "▶ Phase 4: Nuclei Scan"
echo "────────────────────────"

nuclei -update-templates -silent 2>/dev/null || true

nuclei \
  -l "$OUT/live-hosts.txt" \
  -t exposures/,cves/,misconfiguration/,takeovers/ \
  -severity medium,high,critical \
  -rate-limit 50 \
  -bulk-size 25 \
  -timeout 10 \
  -retries 1 \
  -silent \
  -json \
  -o "$OUT/nuclei-results.json" || true

if [[ -s "$OUT/nuclei-results.json" ]]; then
  jq -r '[.info.severity, .host, .info.name, .matched_at] | @tsv' \
    "$OUT/nuclei-results.json" | sort -k1 > "$OUT/nuclei-triage.txt"
  CRITICAL=$(grep -c '^critical' "$OUT/nuclei-triage.txt" 2>/dev/null || echo 0)
  HIGH=$(grep     -c '^high'     "$OUT/nuclei-triage.txt" 2>/dev/null || echo 0)
  MEDIUM=$(grep   -c '^medium'   "$OUT/nuclei-triage.txt" 2>/dev/null || echo 0)
else
  CRITICAL=0; HIGH=0; MEDIUM=0
fi
echo "  Critical : $CRITICAL  High : $HIGH  Medium : $MEDIUM"

# =============================================================================
# PHASE 5 — FFUF CONTENT DISCOVERY (top 10 live hosts)
# =============================================================================
echo ""
echo "▶ Phase 5: FFUF Content Discovery (top 10 hosts)"
echo "──────────────────────────────────────────────────"

WORDLIST="/opt/homebrew/share/seclists/Discovery/Web-Content/raft-medium-directories.txt"
mkdir -p "$OUT/ffuf"

if [[ -f "$WORDLIST" ]]; then
  head -10 "$OUT/live-hosts.txt" | while IFS= read -r HOST; do
    SAFE=$(echo "$HOST" | sed 's|https\?://||' | tr '/:' '__')
    ffuf \
      -u "${HOST}/FUZZ" \
      -w "$WORDLIST" \
      -mc 200,301,302,401,403 \
      -ac -t 40 -timeout 10 -rate 80 \
      -o "$OUT/ffuf/${SAFE}.json" -of json -s 2>/dev/null || true
  done
  echo "  FFUF results in $OUT/ffuf/"
else
  echo "  (skipped — SecLists not found at $WORDLIST)"
  echo "  Install: brew install seclists"
fi

# =============================================================================
# PHASE 6 — FINAL SUMMARY
# =============================================================================
ELAPSED=$((SECONDS - START_TIME))
MINS=$((ELAPSED / 60))
SECS=$((ELAPSED % 60))

echo ""
echo "┌─────────────────────────────────────────────┐"
echo "│   ✓ Recon Pipeline Complete                 │"
echo "├─────────────────────────────────────────────┤"
printf "│   Subdomains discovered : %-18s│\n" "$SUBS"
printf "│   DNS-valid             : %-18s│\n" "$DNS"
printf "│   Live hosts            : %-18s│\n" "$LIVE"
printf "│   Takeover candidates   : %-18s│\n" "$TAKEOVERS"
printf "│   Nuclei Critical       : %-18s│\n" "$CRITICAL"
printf "│   Nuclei High           : %-18s│\n" "$HIGH"
printf "│   Nuclei Medium         : %-18s│\n" "$MEDIUM"
printf "│   Runtime               : %dm %ds           │\n" "$MINS" "$SECS"
echo "├─────────────────────────────────────────────┤"
echo "│   Results: $OUT"
echo "└─────────────────────────────────────────────┘"
