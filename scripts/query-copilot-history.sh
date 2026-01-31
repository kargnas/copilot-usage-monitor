#!/bin/bash
# Query GitHub Copilot usage history via browser cookies
# Requires: Python 3, uv, cryptography package
#
# Usage:
#   ./query-copilot-history.sh --list           # List available browser profiles
#   ./query-copilot-history.sh --profile 17     # Use specific profile
#   ./query-copilot-history.sh --profile 17 --summary  # Summary only
#   ./query-copilot-history.sh --profile 17 --json     # Full JSON output

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check for uv
if ! command -v uv &> /dev/null; then
    echo "Error: uv is required. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Run the Python script
cd "$PROJECT_DIR"
exec uv run python3 "$SCRIPT_DIR/github_copilot_history.py" "$@"
