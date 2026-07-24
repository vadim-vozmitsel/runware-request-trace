#!/usr/bin/env bash
#
# Read-only production check. Confirms the current package version and
# validates the live request schema this demo depends on.

set -euo pipefail

pinned_version="$(node -p "require('./package.json').dependencies['@runware/sdk']")"
current_version="$(npm view @runware/sdk version)"

if [ "$pinned_version" != "$current_version" ]; then
  echo "warning: @runware/sdk pinned at $pinned_version, npm currently has $current_version." >&2
  echo "         Not a failure. Update package.json and re-check the schema below if you upgrade." >&2
fi

check_schema() {
  local air="$1"
  local expected_task_type="$2"
  local expected_delivery="$3"
  local schema

  schema="$(curl -fsSL "https://schemas.runware.ai/resolve/$air")"

  jq -e \
    --arg task_type "$expected_task_type" \
    --arg delivery "$expected_delivery" \
    '
      .requestSchema.properties.taskType.const == $task_type
      and (.requestSchema.required | index("taskUUID") != null)
      and (.requestSchema.required | index("model") != null)
      and (
        .requestSchema.properties.deliveryMethod.oneOf
        | map(.const)
        | index($delivery) != null
      )
    ' <<<"$schema" >/dev/null

  echo "ok: $air -> $expected_task_type supports $expected_delivery"
}

check_schema "runware:100@1" "imageInference" "sync"

echo "ok: @runware/sdk is $current_version"
echo "The live contract is current."
