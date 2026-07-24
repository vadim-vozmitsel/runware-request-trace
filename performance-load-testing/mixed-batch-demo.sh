#!/usr/bin/env bash
#
# Submits one HTTP request containing three unrelated task types (image
# generation, text-to-speech, and a chat completion) in a single JSON
# array, and prints the curl timing breakdown alongside the response.
#
# This checks one specific, narrow thing: whether the API accepts and
# correctly processes multiple different task types in one request. It
# does not show, and should not be described as showing, how or where
# each task type is executed internally (which hardware it lands on,
# whether it runs in parallel, etc.). That's not observable from an HTTP
# client, so this script's result is evidence of API-level flexibility
# only, not a routing or scheduling claim.
#
# Usage:
#   cp ../.env.example ../.env && edit it, or export RUNWARE_API_KEY yourself
#   ./mixed-batch-demo.sh
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

[ -n "${RUNWARE_API_KEY:-}" ] || { echo "No API key found. Put it in .env (see .env.example) or export RUNWARE_API_KEY." >&2; exit 1; }

payload() {
  cat <<EOF
[
  {"taskType":"imageInference","taskUUID":"$(uuidgen | tr 'A-Z' 'a-z')","model":"runware:100@1","positivePrompt":"a lighthouse on a rocky cliff at dusk","width":512,"height":512,"includeCost":true,"deliveryMethod":"sync"},
  {"taskType":"audioInference","taskUUID":"$(uuidgen | tr 'A-Z' 'a-z')","model":"minimax:speech@2.8","speech":{"text":"One request, three task types.","voice":"English_expressive_narrator"},"includeCost":true,"deliveryMethod":"sync"},
  {"taskType":"textInference","taskUUID":"$(uuidgen | tr 'A-Z' 'a-z')","model":"minimax:m3@0","messages":[{"role":"user","content":"In one sentence, what does it mean for an API to accept mixed task types in a single request?"}],"includeCost":true,"deliveryMethod":"sync"}
]
EOF
}

tmp="$(mktemp)"
curl -s -o "$tmp" -w '\nhttp_code=%{http_code} dns=%{time_namelookup}s connect=%{time_connect}s tls=%{time_appconnect}s ttfb=%{time_starttransfer}s total=%{time_total}s\n' \
  -X POST https://api.runware.ai/v1 \
  -H "Authorization: Bearer $RUNWARE_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "$(payload)"
jq '.' "$tmp"
rm -f "$tmp"
