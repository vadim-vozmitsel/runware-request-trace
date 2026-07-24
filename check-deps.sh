#!/usr/bin/env bash
# Verifies the tools these scripts depend on are present before you run
# anything else in this repo, and confirms an API key is present.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load RUNWARE_API_KEY from .env unless it's already set in the environment.
if [ -z "${RUNWARE_API_KEY:-}" ] && [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/.env"
  set +a
fi

missing=0

check() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "  ok: $1"
  else
    echo "  missing: $1 ($2)"
    missing=1
  fi
}

echo "Checking dependencies..."
check curl "https://curl.se, usually preinstalled on macOS/Linux"
check jq "brew install jq / apt install jq"
check uuidgen "usually preinstalled on macOS/Linux"
check node "https://nodejs.org"
check npm "installed with Node.js"

echo
if [ -n "${RUNWARE_API_KEY:-}" ]; then
  echo "  ok: RUNWARE_API_KEY is set"
else
  echo "  missing: RUNWARE_API_KEY is not available. Either:"
  echo "    cp .env.example .env   # then edit .env and fill in your key"
  echo "    export RUNWARE_API_KEY=your_key_here"
  missing=1
fi

echo
if [ "$missing" -eq 0 ]; then
  echo "All set. Next: ./verify-live-contract.sh"
else
  echo "Fix the items above, then re-run this check."
  exit 1
fi
