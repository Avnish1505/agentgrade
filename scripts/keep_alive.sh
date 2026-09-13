#!/bin/sh
# Pings the authorised org and logs a dated check into PROGRESS.md.

ORG_ALIAS="agentgrade"
PROGRESS_FILE="$(dirname "$0")/../PROGRESS.md"
TODAY="$(date '+%Y-%m-%d')"

sf org display --target-org "$ORG_ALIAS"
STATUS=$?

echo "$TODAY"

if [ "$STATUS" -eq 0 ]; then
  echo "| $TODAY | keep_alive | org '$ORG_ALIAS' reachable | |" >> "$PROGRESS_FILE"
else
  echo "| $TODAY | keep_alive | org '$ORG_ALIAS' check FAILED | see script output |" >> "$PROGRESS_FILE"
fi
