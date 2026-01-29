#!/bin/bash
# Query all AI provider usage at once

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "    AI Usage Monitor - All Providers"
echo "    $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

for script in query-claude.sh query-codex.sh query-copilot.sh query-gemini-cli.sh query-antigravity-local.sh; do
    if [[ -x "$SCRIPT_DIR/$script" ]]; then
        "$SCRIPT_DIR/$script" 2>/dev/null || echo "$script: Failed"
        echo ""
    fi
done

echo "========================================"
echo "Done"
