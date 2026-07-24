#!/usr/bin/env bash
#
# Compares a FLUX.1 Schnell image request with and without
# acceleratorOptions (TeaCache) to check for a real cost or time delta.
# Runs N repeats of each condition sequentially and reports medians; a
# single-sample comparison is noisy, the same lesson the concurrency probe
# already taught.
#
# Usage:
#   cp ../.env.example ../.env && edit it, or export RUNWARE_API_KEY yourself
#   ./accelerator-probe.sh                # 5 runs each condition
#   RUNS=10 ./accelerator-probe.sh
#   MODEL="runware:400@1" ./accelerator-probe.sh   # a heavier model

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
[ -n "${RUNWARE_API_KEY:-}" ] || { echo "No API key found. Put it in .env (see .env.example) or export RUNWARE_API_KEY." >&2; exit 1; }

MODEL="${MODEL:-runware:100@1}"
RUNS="${RUNS:-5}"
WIDTH="${WIDTH:-512}"
HEIGHT="${HEIGHT:-512}"
PROMPT="${PROMPT:-a lighthouse on a rocky cliff at dusk}"
STEPS="${STEPS:-}"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
CSV="$RESULTS_DIR/accelerator-$STAMP.csv"

payload() {
  local accel="$1" extra="" steps_field=""
  if [ "$accel" = "on" ]; then
    extra=',"acceleratorOptions":{"teaCache":true,"teaCacheDistance":0.5}'
  fi
  if [ -n "$STEPS" ]; then
    steps_field=",\"steps\":$STEPS"
  fi
  cat <<EOF
[{"taskType":"imageInference","taskUUID":"$(uuidgen | tr 'A-Z' 'a-z')",
"positivePrompt":"$PROMPT","width":$WIDTH,"height":$HEIGHT,
"model":"$MODEL","numberResults":1,"includeCost":true,"deliveryMethod":"sync"$extra$steps_field}]
EOF
}

run_one() {
  local accel="$1" idx="$2" tmp; tmp="$(mktemp)"
  local timing
  timing=$(curl -s -o "$tmp" -w "%{http_code},%{time_total}" \
    -X POST https://api.runware.ai/v1 \
    -H "Authorization: Bearer $RUNWARE_API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary "$(payload "$accel")")
  local cost
  cost=$(jq -r '.data[0].cost // "n/a"' "$tmp" 2>/dev/null || echo "n/a")
  local err
  err=$(jq -r '.errors[0].message // empty' "$tmp" 2>/dev/null || true)
  if [ -n "$err" ]; then
    echo "  $accel run $idx ERROR: $err" >&2
    cat "$tmp" >&2
  fi
  echo "$accel,$idx,$timing,$cost" >> "$CSV"
  echo "  $accel run $idx: ${timing}s, cost \$${cost}"
  rm -f "$tmp"
}

echo "Model: $MODEL (${WIDTH}x${HEIGHT}), $RUNS runs per condition"
echo "accelerator,run,http_code,total_s,cost_usd" > "$CSV"

echo
echo "Baseline, no acceleratorOptions:"
for i in $(seq 1 "$RUNS"); do run_one "off" "$i"; done

echo
echo "With acceleratorOptions (teaCache: true, teaCacheDistance: 0.5):"
for i in $(seq 1 "$RUNS"); do run_one "on" "$i"; done

median_col() {
  grep "^$1," "$CSV" | cut -d, -f4 | sort -n | awk '{a[NR]=$1} END {print (NR%2==1) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2}'
}
median_cost() {
  grep "^$1," "$CSV" | cut -d, -f5 | sort -n | awk '{a[NR]=$1} END {print (NR%2==1) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2}'
}

echo
echo "Median total, off: $(median_col off)s   cost: \$$(median_cost off)"
echo "Median total, on:  $(median_col on)s   cost: \$$(median_cost on)"
echo "Results: $CSV"
echo "Method: curl -w total_s, sync REST, $MODEL, ${WIDTH}x${HEIGHT}, $RUNS runs per condition, from $(hostname), $(date +%F)."
