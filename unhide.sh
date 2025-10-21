#!/usr/bin/env bash
# unhide-all-b2.sh
# Unhides all hidden files in a Backblaze B2 bucket (optionally within a prefix).
# Usage: ./unhide-all-b2.sh <bucketName> [prefix] [--dry-run]
# Example: ./unhide-all-b2.sh my-bucket some/folder --dry-run

set -euo pipefail

if ! command -v b2 >/dev/null 2>&1; then
  echo "ERROR: b2 CLI not found in PATH." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required." >&2
  exit 1
fi

BUCKET="${1:-}"
PREFIX="${2:-}"
DRY_RUN="${3:-}"

if [[ -z "$BUCKET" ]]; then
  echo "Usage: $0 <bucketName> [prefix] [--dry-run]" >&2
  exit 1
fi

# Build B2 URI
if [[ -n "$PREFIX" ]]; then
  # Ensure trailing slash for directory prefix
  [[ "$PREFIX" != */ ]] && PREFIX="${PREFIX}/"
  TARGET_URI="b2://${BUCKET}/${PREFIX}"
else
  TARGET_URI="b2://${BUCKET}"
fi

echo "Scanning for hidden files under: ${TARGET_URI}"
# We list ALL versions and pick only those with action == "hide".
# Then we extract unique fileName(s) to unhide (one unhide per name).
# Notes:
#  - --versions shows all versions (so we can detect hide markers)
#  - --recursive walks the prefix
#  - --json gives us machine-readable output
#  - Some CLI builds emit an array; others emit one JSON object per line.
#    The jq below handles both.
HIDDEN_NAMES=$(
  b2 ls --versions --recursive --json "${TARGET_URI}" \
  | jq -r '
      (if type=="array" then .[] else . end)
      | select((.action? // .fileAction? // "") == "hide")
      | .fileName
    ' \
  | sort -u
)

if [[ -z "$HIDDEN_NAMES" ]]; then
  echo "No hidden files found. Nothing to do."
  exit 0
fi

COUNT=$(printf "%s\n" "$HIDDEN_NAMES" | wc -l | tr -d ' ')
echo "Found ${COUNT} hidden file name(s)."

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo "Dry run mode. Commands that would run:"
  printf "%s\n" "$HIDDEN_NAMES" | sed -e "s/^/b2 file unhide ${BUCKET} /"
  exit 0
fi

# Do the work
FAILED=0
while IFS= read -r NAME; do
  echo "Unhiding: ${NAME}"
  if ! b2 file unhide "b2://${BUCKET}/${NAME}"; then
    echo "ERROR: Failed to unhide ${NAME}" >&2
    FAILED=$((FAILED+1))
  fi
done <<< "$HIDDEN_NAMES"

if [[ $FAILED -gt 0 ]]; then
  echo "Completed with ${FAILED} failure(s)." >&2
  exit 2
else
  echo "All hidden files successfully unhidden."
fi
