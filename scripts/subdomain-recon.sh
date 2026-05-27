#!/usr/bin/env bash
# =============================================================================
# subdomain-recon.sh — PhantomRed Subdomain Recon Automation
# =============================================================================
# Usage:   ./scripts/subdomain-recon.sh <target.com>
# Example: ./scripts/subdomain-recon.sh hackerone.com
#
# Stages:
#   1. Passive enumeration  (subfinder + assetfinder + amass passive)
#   2. DNS validation       (dnsx)
#   3. CNAME / takeover     (dnsx -cname)
#   4. Live host probing    (httpx)
#   5. Delta detection      (diff vs previous run)
#
# Requirements: subfinder, assetfinder, amass, dnsx, httpx
# Install:  go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
#           go install github.com/tomnomnom/assetfinder@latest
#           go install github.com/owasp-amass/amass/v4/...@master
#           go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
#           go install github.com/projectdiscovery/httpx/cmd/httpx@latest
# =============================================================================

set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target.com>"
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUT="./output/${TARGET}/${TIMESTAMP}"
PREV="./output/${TARGET}/latest"
mkdir -p "$OUT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PhantomRed — Subdomain Recon Pipeline"
echo "  Target : $TARGET"
echo "  Output : $OUT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# -----------------------------------------------------------------------------
# STAGE 1 — Passive subdomain enumeration (parallel, zero footprint)
# -----------------------------------------------------------------------------
echo ""
echo "[1/5] Passive enumeration..."

subfinder -d "$TARGET" -silent -all -o "$OUT/sf.txt" &
assetfinder --subs-only "$TARGET" > "$OUT/af.txt" &
amass enum -passive -d "$TARGET" -o "$OUT/am.txt" 2>/dev/null &
wait

# Merge and deduplicate
cat "$OUT/sf.txt" "$OUT/af.txt" "$OUT/am.txt" 2>/dev/null \
  | sort -u \
  > "$OUT/subs-passive.txt"

PASSIVE_COUNT=$(wc -l < "$OUT/subs-passive.txt")
echo "    Passive subdomains : $PASSIVE_COUNT"

# -----------------------------------------------------------------------------
# STAGE 2 — DNS validation
# -----------------------------------------------------------------------------
echo ""
echo "[2/5] DNS validation..."

dnsx \
  -l "$OUT/subs-passive.txt" \
  -silent \
  -o "$OUT/dns-valid.txt"

DNS_COUNT=$(wc -l < "$OUT/dns-valid.txt")
echo "    DNS-valid          : $DNS_COUNT"

# -----------------------------------------------------------------------------
# STAGE 3 — CNAME / takeover detection
# -----------------------------------------------------------------------------
echo ""
echo "[3/5] CNAME takeover detection..."

dnsx \
  -l "$OUT/subs-passive.txt" \
  -cname \
  -silent \
  | grep -E 'amazonaws|github\.io|heroku|azurewebsites|shopify|fastly|netlify|ghost\.io|surge\.sh|pantheon|wpengine' \
  > "$OUT/potential-takeovers.txt" 2>/dev/null || true

TAKEOVER_COUNT=$(wc -l < "$OUT/potential-takeovers.txt")
echo "    Potential takeovers: $TAKEOVER_COUNT"
if [[ "$TAKEOVER_COUNT" -gt 0 ]]; then
  echo "    ⚠ Review: $OUT/potential-takeovers.txt"
fi

# -----------------------------------------------------------------------------
# STAGE 4 — Live host probing
# -----------------------------------------------------------------------------
echo ""
echo "[4/5] Live host probing..."

httpx \
  -l "$OUT/dns-valid.txt" \
  -silent \
  -threads 50 \
  -timeout 10 \
  -tech-detect \
  -status-code \
  -o "$OUT/live-hosts.txt"

LIVE_COUNT=$(wc -l < "$OUT/live-hosts.txt")
echo "    Live hosts         : $LIVE_COUNT"

# -----------------------------------------------------------------------------
# STAGE 5 — Delta detection vs previous run
# -----------------------------------------------------------------------------
echo ""
echo "[5/5] Delta detection..."

if [[ -f "$PREV/live-hosts.txt" ]]; then
  comm -13 \
    <(sort "$PREV/live-hosts.txt") \
    <(sort "$OUT/live-hosts.txt") \
    > "$OUT/new-hosts.txt"
  NEW_COUNT=$(wc -l < "$OUT/new-hosts.txt")
  echo "    New hosts (delta)  : $NEW_COUNT"
else
  echo "    No previous run found — skipping delta"
  cp "$OUT/live-hosts.txt" "$OUT/new-hosts.txt"
fi

# Update 'latest' symlink
rm -f "$PREV"
ln -s "$OUT" "$PREV"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Recon complete"
echo "  Passive subdomains : $PASSIVE_COUNT"
echo "  DNS-valid          : $DNS_COUNT"
echo "  Live hosts         : $LIVE_COUNT"
echo "  Potential takeovers: $TAKEOVER_COUNT"
echo "  Results            : $OUT/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
