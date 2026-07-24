#!/usr/bin/env bash
#
# Fires N Runware imageInference calls at the same instant (not sequentially,
# see latency-probe.sh for the sequential baseline) to measure latency and
# error rate under real concurrent load. Every request runs as a background
# job launched together, then the script waits for all of them.
#
# Usage:
#   cp ../.env.example ../.env && edit it, or export RUNWARE_API_KEY yourself
#   CONCURRENCY=1 ./concurrent-load-probe.sh          # baseline: one request
#   CONCURRENCY=30 ./concurrent-load-probe.sh         # the cold open

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
CONCURRENCY="${CONCURRENCY:-5}"
WIDTH="${WIDTH:-512}"
HEIGHT="${HEIGHT:-512}"
PROMPT="${PROMPT:-a lighthouse on a rocky cliff at dusk}"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
CSV="$RESULTS_DIR/concurrent-$STAMP.csv"
WORK_TMP_DIR="$(mktemp -d)"

[ -n "${RUNWARE_API_KEY:-}" ] || { echo "No API key found. Put it in .env (see .env.example) or export RUNWARE_API_KEY." >&2; exit 1; }

payload() {
  cat <<EOF
[{"taskType":"imageInference","taskUUID":"$(uuidgen | tr 'A-Z' 'a-z')",
"positivePrompt":"$PROMPT","width":$WIDTH,"height":$HEIGHT,
"model":"$MODEL","numberResults":1,"includeCost":true,"deliveryMethod":"sync"}]
EOF
}

run_one() {
  local idx="$1" tmp; tmp="$(mktemp)"
  local timing
  timing=$(curl -s -o "$tmp" -w "%{http_code},%{time_namelookup},%{time_connect},%{time_appconnect},%{time_starttransfer},%{time_total}" \
    -X POST https://api.runware.ai/v1 \
    -H "Authorization: Bearer $RUNWARE_API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary "$(payload)")
  local cost
  cost=$(jq -r '.data[0].cost // "n/a"' "$tmp" 2>/dev/null || echo "n/a")
  echo "$MODEL,$idx,$timing,$cost" > "$WORK_TMP_DIR/$idx.row"
  rm -f "$tmp"
}

echo "Firing $CONCURRENCY concurrent requests against $MODEL (${WIDTH}x${HEIGHT})..."
LAUNCH_START=$(date +%s.%N)
for i in $(seq 1 "$CONCURRENCY"); do
  run_one "$i" &
done
wait
LAUNCH_END=$(date +%s.%N)

echo "model,run,http_code,dns_s,connect_s,tls_s,ttfb_s,total_s,cost_usd" > "$CSV"
for i in $(seq 1 "$CONCURRENCY"); do
  cat "$WORK_TMP_DIR/$i.row" >> "$CSV"
done
rm -rf "$WORK_TMP_DIR"

echo
echo "Per-request results (all fired at the same instant):"
tail -n +2 "$CSV" | while IFS=, read -r model run code dns conn tls ttfb total cost; do
  echo "  run $run: total ${total}s, ttfb ${ttfb}s, cost \$${cost}"
done

echo
echo "Median total (concurrent batch):"
tail -n +2 "$CSV" | cut -d, -f8 | sort -n | awk '{a[NR]=$1} END {print (NR%2==1) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2, "s"}'
echo "Wall-clock, launch to last finish: $(awk -v a="$LAUNCH_START" -v b="$LAUNCH_END" 'BEGIN{printf "%.3f", b-a}')s"
echo "Results: $CSV"
echo "Method: curl -w breakdown, $CONCURRENCY simultaneous sync REST calls (fired in parallel, not sequential), $MODEL, ${WIDTH}x${HEIGHT}, from $(hostname), $(date +%F)."
