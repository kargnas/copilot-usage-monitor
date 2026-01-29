#!/bin/bash
# Query GitHub Copilot usage via OpenCode auth
# Token location: ~/.local/share/opencode/auth.json

set -e

AUTH_FILE="$HOME/.local/share/opencode/auth.json"

if [[ ! -f "$AUTH_FILE" ]]; then
    echo "Error: OpenCode auth file not found at $AUTH_FILE"
    exit 1
fi

ACCESS=$(jq -r '.["github-copilot"].access // empty' "$AUTH_FILE")

if [[ -z "$ACCESS" ]]; then
    echo "Error: No GitHub Copilot token found in auth file"
    exit 1
fi

echo "=== GitHub Copilot Usage ==="
echo ""

curl -s "https://api.github.com/copilot_internal/user" \
    -H "Authorization: token $ACCESS" \
    -H "Accept: application/json" \
    -H "Editor-Version: vscode/1.96.2" \
    -H "X-Github-Api-Version: 2025-04-01" | jq '
{
    "plan": .copilot_plan,
    "reset_date": .quota_reset_date,
    "chat_remaining": .quota_snapshots.chat.remaining,
    "completions_remaining": .quota_snapshots.completions.remaining,
    "premium_entitlement": .quota_snapshots.premium_interactions.entitlement,
    "premium_remaining": .quota_snapshots.premium_interactions.remaining,
    "premium_overage_permitted": .quota_snapshots.premium_interactions.overage_permitted
}'
