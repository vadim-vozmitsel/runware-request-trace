#!/usr/bin/env bash
#
# Measures the latency budget of a single Runware imageInference call,
# one request at a time. Reports the curl timing breakdown (DNS, TCP
# connect, TLS handshake, time to first byte, total) plus per-call cost.
# See concurrent-load-probe.sh for the equivalent measurement under
# simultaneous load, and METHODOLOGY.md for how to read the output.
#
# Usage:
#   cp ../.env.example ../.env && edit it, or export RUNWARE_API_KEY yourself
#   ./latency-probe.sh                          # 1 warmup + 5 measured runs
#   MODEL="runware:400@1" RUNS=10 ./latency-probe.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load RUNWARE_API_KEY from .env (this directory or its parent) unless it's
# already set in the environment. Exported vars always take precedence.
if [ -z "${RUNWARE_API_KEY:-}" ]; then
  for envfile in "$SCRIPT_DIR/.env" "$SCRIPT_DIR/../.env"; do
    if [ -f "$envfile" ]; then
      set -a
      # shellcheck disable=SC1090
      source "$envfile"
      set +a
      break
    fi
  done
fi

MODEL="${MODEL:-runware:100@1}"
RUNS="${RUNS:-5}"
WIDTH="${WIDTH:-512}"
HEIGHT="${HEIGHT:-512}"
PROMPT="${PROMPT:-a lighthouse on a rocky cliff at dusk}"
OUTDIR="$SCRIPT_DIR/results"
mkdir -p "$OUTDIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
CSV="$OUTDIR/latency-$STAMP.csv"

[ -n "${RUNWARE_API_KEY:-}" ] || { echo "No API key found. Put it in .env (see .env.example) or export RUNWARE_API_KEY." >&2; exit 1; }

payload() {
  cat <<EOF
[{"taskType":"imageInference","taskUUID":"$(uuidgen | tr 'A-Z' 'a-z')",
"positivePrompt":"$PROMPT","width":$WIDTH,"height":$HEIGHT,
"model":"$MODEL","numberResults":1,"includeCost":true,"deliveryMethod":"sync"}]
EOF
}

echo "model,run,http_code,dns_s,connect_s,tls_s,ttfb_s,total_s,cost_usd" > "$CSV"

run_once() {
  local label="$1" tmp; tmp="$(mktemp)"
  local timing
  timing=$(curl -s -o "$tmp" -w "%{http_code},%{time_namelookup},%{time_connect},%{time_appconnect},%{time_starttransfer},%{time_total}" \
    -X POST https://api.runware.ai/v1 \
    -H "Authorization: Bearer $RUNWARE_API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary "$(payload)")
  local cost
  cost=$(jq -r '.data[0].cost // "n/a"' "$tmp" 2>/dev/null || echo "n/a")
  local err
  err=$(jq -r '.errors[0].message // empty' "$tmp" 2>/dev/null || true)
  [ -n "$err" ] && echo "  run $label ERROR: $err" >&2
  echo "$MODEL,$label,$timing,$cost" >> "$CSV"
  echo "  run $label: total $(echo "$timing" | cut -d, -f6)s, ttfb $(echo "$timing" | cut -d, -f5)s, cost \$${cost}"
  rm -f "$tmp"
}

echo "Model: $MODEL (${WIDTH}x${HEIGHT}), $RUNS measured runs"
echo "Warmup (not counted):"
run_once "warmup"
echo "Measured:"
for i in $(seq 1 "$RUNS"); do run_once "$i"; done

echo
echo "Median total (measured runs only):"
tail -n +3 "$CSV" | cut -d, -f8 | sort -n | awk '{a[NR]=$1} END {print (NR%2==1) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2, "s"}'
echo "Results: $CSV"
echo "Method: curl -w breakdown, sync REST, $MODEL, ${WIDTH}x${HEIGHT}, from $(hostname), $(date +%F)."
