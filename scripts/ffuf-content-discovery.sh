#!/usr/bin/env bash
# =============================================================================
# ffuf-content-discovery.sh — PhantomRed FFUF Content Discovery Pipeline
# =============================================================================
# Usage:   ./scripts/ffuf-content-discovery.sh <live-hosts.txt> [wordlist]
# Example: ./scripts/ffuf-content-discovery.sh output/target.com/latest/live-hosts.txt
#
# Modes (run in sequence):
#   1. Directory fuzzing       — find hidden paths and endpoints
#   2. Backup file detection   — .bak, .old, .zip, config files
#   3. Parameter fuzzing       — discover hidden GET parameters
#
# Requirements: ffuf, jq
# Install:  go install github.com/ffuf/ffuf/v2@latest
# Wordlist: https://github.com/danielmiessler/SecLists
# =============================================================================

set -euo pipefail

HOSTS="${1:-}"
if [[ -z "$HOSTS" || ! -f "$HOSTS" ]]; then
  echo "Usage: $0 <live-hosts.txt> [wordlist-path]"
  exit 1
fi

# Default wordlist — adjust path to your SecLists location
WORDLIST="${2:-/opt/homebrew/share/seclists/Discovery/Web-Content/raft-medium-directories.txt}"
BACKUP_LIST="${3:-/opt/homebrew/share/seclists/Discovery/Web-Content/raft-medium-files.txt}"

if [[ ! -f "$WORDLIST" ]]; then
  echo "ERROR: Wordlist not found at $WORDLIST"
  echo "Install SecLists: brew install seclists"
  exit 1
fi

OUTDIR="./output/ffuf/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

HOST_COUNT=$(wc -l < "$HOSTS")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PhantomRed — FFUF Content Discovery"
echo "  Hosts    : $HOST_COUNT"
echo "  Wordlist : $WORDLIST"
echo "  Output   : $OUTDIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Process each host
while IFS= read -r HOST; do
  # Sanitize hostname for use as filename
  SAFE=$(echo "$HOST" | sed 's|https\?://||' | tr '/:' '__')
  mkdir -p "$OUTDIR/$SAFE"

  echo ""
  echo "  → $HOST"

  # -------------------------------------------------------------------
  # MODE 1: Directory fuzzing
  # -------------------------------------------------------------------
  echo "    [1/3] Directory fuzzing..."
  ffuf \
    -u "${HOST}/FUZZ" \
    -w "$WORDLIST" \
    -mc 200,201,204,301,302,307,401,403,405 \
    -ac \
    -t 50 \
    -timeout 10 \
    -rate 100 \
    -o "$OUTDIR/$SAFE/dirs.json" \
    -of json \
    -s 2>/dev/null || true

  # Extract discovered paths
  if [[ -s "$OUTDIR/$SAFE/dirs.json" ]]; then
    jq -r '.results[] | [.status, .length, .url] | @tsv' \
      "$OUTDIR/$SAFE/dirs.json" \
      > "$OUTDIR/$SAFE/dirs.txt" 2>/dev/null || true
    DIR_COUNT=$(wc -l < "$OUTDIR/$SAFE/dirs.txt")
    echo "      Found: $DIR_COUNT paths"
  fi

  # -------------------------------------------------------------------
  # MODE 2: Backup / sensitive file detection
  # -------------------------------------------------------------------
  if [[ -f "$BACKUP_LIST" ]]; then
    echo "    [2/3] Backup file detection..."
    ffuf \
      -u "${HOST}/FUZZ" \
      -w "$BACKUP_LIST" \
      -mc 200,201,204 \
      -t 30 \
      -timeout 10 \
      -rate 50 \
      -o "$OUTDIR/$SAFE/backups.json" \
      -of json \
      -s 2>/dev/null || true

    if [[ -s "$OUTDIR/$SAFE/backups.json" ]]; then
      jq -r '.results[] | [.status, .length, .url] | @tsv' \
        "$OUTDIR/$SAFE/backups.json" \
        > "$OUTDIR/$SAFE/backups.txt" 2>/dev/null || true
      BACKUP_COUNT=$(wc -l < "$OUTDIR/$SAFE/backups.txt")
      if [[ "$BACKUP_COUNT" -gt 0 ]]; then
        echo "      ⚠ Backup files found: $BACKUP_COUNT"
      fi
    fi
  else
    echo "    [2/3] Skipping backup scan (wordlist not found)"
  fi

  # -------------------------------------------------------------------
  # MODE 3: GET parameter fuzzing (on discovered endpoints)
  # -------------------------------------------------------------------
  echo "    [3/3] Parameter fuzzing..."
  PARAM_LIST="/opt/homebrew/share/seclists/Discovery/Web-Content/burp-parameter-names.txt"
  if [[ -f "$PARAM_LIST" && -s "$OUTDIR/$SAFE/dirs.txt" ]]; then
    # Fuzz top discovered path for hidden parameters
    FIRST_PATH=$(awk '{print $3}' "$OUTDIR/$SAFE/dirs.txt" | head -1)
    if [[ -n "$FIRST_PATH" ]]; then
      ffuf \
        -u "${FIRST_PATH}?FUZZ=test" \
        -w "$PARAM_LIST" \
        -mc 200,201,204 \
        -fs 0 \
        -t 30 \
        -timeout 10 \
        -o "$OUTDIR/$SAFE/params.json" \
        -of json \
        -s 2>/dev/null || true
    fi
  else
    echo "      (skipped — no paths discovered or wordlist missing)"
  fi

done < "$HOSTS"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ FFUF content discovery complete"
echo "  Results : $OUTDIR/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
