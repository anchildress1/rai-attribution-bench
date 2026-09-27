#!/usr/bin/env bash
# Render the three variant tasks and push each with the cases dataset attached.
set -euo pipefail
cd "$(dirname "$0")/.."

DATASET=anchildress1/ai-attribution-honesty-cases

uv run python task/render.py
for file in task/variants/*.py; do
  slug=$(basename "$file" .py)
  # Pushing without -d silently detaches the dataset from the new version.
  uv run kaggle b t push "$slug" -f "$file" -d "$DATASET" --wait
done
