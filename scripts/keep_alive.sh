#!/bin/sh
# Pings the authorised org, retrieves agent metadata via manifest, and logs
# a dated check into PROGRESS.md. This org has no source tracking, so
# `sf project retrieve start` needs a manifest every time.

ORG_ALIAS="agentgrade"
SCRIPT_DIR="$(dirname "$0")"
PROGRESS_FILE="$SCRIPT_DIR/../PROGRESS.md"
MANIFEST="$SCRIPT_DIR/../manifest/agentgrade-retrieve.xml"
TODAY="$(date '+%Y-%m-%d')"

sf org display --target-org "$ORG_ALIAS"
DISPLAY_STATUS=$?

echo "$TODAY"

sf project retrieve start --manifest "$MANIFEST" --target-org "$ORG_ALIAS"
RETRIEVE_STATUS=$?
if [ "$RETRIEVE_STATUS" -ne 0 ]; then
  echo "WARNING: manifest retrieve failed (exit $RETRIEVE_STATUS)" >&2
fi

if [ "$DISPLAY_STATUS" -eq 0 ] && [ "$RETRIEVE_STATUS" -eq 0 ]; then
  echo "| $TODAY | keep_alive | org reachable, retrieve OK | |" >> "$PROGRESS_FILE"
else
  echo "| $TODAY | keep_alive | org check or retrieve FAILED | see script output |" >> "$PROGRESS_FILE"
fi
