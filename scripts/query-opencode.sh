#!/bin/bash
# Query OpenCode (Zen) usage statistics
# Uses: opencode stats command
# Data source: Local session data

set -e

OPENCODE_BIN="$HOME/.opencode/bin/opencode"

if [[ ! -x "$OPENCODE_BIN" ]]; then
    echo "Error: OpenCode CLI not found at $OPENCODE_BIN"
    exit 1
fi

# Default to last 30 days
DAYS="${1:-30}"

echo "=== OpenCode Usage (Last $DAYS Days) ==="
echo ""

# Run opencode stats with models breakdown
"$OPENCODE_BIN" stats --days "$DAYS" --models 10 --tools 10 2>&1

# Also show per-project breakdown if requested
if [[ "$2" == "--projects" ]]; then
    echo ""
    echo "=== Per-Project Breakdown ==="
    
    # Get list of recent projects from sessions
    SESSIONS_DIR="$HOME/.local/share/opencode/sessions"
    if [[ -d "$SESSIONS_DIR" ]]; then
        # Find unique project paths from recent sessions
        find "$SESSIONS_DIR" -name "*.json" -mtime -"$DAYS" -exec jq -r '.cwd // empty' {} \; 2>/dev/null | \
            sort | uniq -c | sort -rn | head -10
    fi
fi
