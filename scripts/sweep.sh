#!/usr/bin/env bash
# Run each variant task against each model, one run at a time.
# Usage: scripts/sweep.sh [model ...]   (defaults to the full list below)
set -euo pipefail
cd "$(dirname "$0")/.."

# gemini-3.7-flash isn't listed: the platform runs it on every task after each push.
# 3.8 Flash isn't either; one Flash model is enough.
MODELS=(
  gemini-3.5-flash-lite
  gemini-3.1-pro-preview
  gpt-5.6-luna
  gpt-5.6-terra
  gpt-6-astra
  claude-haiku-4-5-20251001
  claude-sonnet-5-default
  claude-opus-5-default
)
if [[ $# -gt 0 ]]; then
  MODELS=("$@")
fi

SLUGS=()
for file in task/variants/*.py; do
  SLUGS+=("$(basename "$file" .py)")
done

MAX_STATUS_FAILURES=10
failures=0

# True while any variant task has a run in flight. A status call that fails counts as
# busy, so an outage never lets a second run start alongside the first; one that keeps
# failing (an expired login, a task never pushed) stops the sweep instead of hanging it.
busy() {
  local slug out
  for slug in "${SLUGS[@]}"; do
    if ! out=$(uv run kaggle b t status "$slug" 2>&1); then
      failures=$((failures + 1))
      echo "status of $slug failed ($failures/$MAX_STATUS_FAILURES): ${out##*$'\n'}" >&2
      if ((failures >= MAX_STATUS_FAILURES)); then
        echo "stopping: kaggle status keeps failing" >&2
        exit 1
      fi
      return 0
    fi
    if grep -qE "Queued|Running|Pending" <<<"$out"; then
      failures=0
      return 0
    fi
  done
  # Reset only after a pass with no failure: a later task failing on every pass must
  # still add up, even while earlier ones answer.
  failures=0
  return 1
}

for slug in "${SLUGS[@]}"; do
  for model in "${MODELS[@]}"; do
    # One run at a time across all tasks: the proxy reserves each call's worst-case
    # cost from a shared quota, and parallel runs drained it before most rows answered.
    while busy; do sleep 30; done
    uv run kaggle b t run "$slug" -m "$model"
    sleep 30
  done
done
while busy; do sleep 30; done
