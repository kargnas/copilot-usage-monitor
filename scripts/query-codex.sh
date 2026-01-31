#!/bin/bash
# Query Codex (OpenAI/ChatGPT) usage via OpenCode auth
# Token: ~/.local/share/opencode/auth.json

set -e

AUTH_FILE="$HOME/.local/share/opencode/auth.json"

if [[ ! -f "$AUTH_FILE" ]]; then
    echo "Error: OpenCode auth file not found at $AUTH_FILE"
    exit 1
fi

ACCESS=$(jq -r '.openai.access // empty' "$AUTH_FILE")
ACCOUNT_ID=$(jq -r '.openai.accountId // empty' "$AUTH_FILE")

if [[ -z "$ACCESS" ]]; then
    echo "Error: No OpenAI token found in auth file"
    exit 1
fi

echo "=== Codex (OpenAI) Usage ==="
echo ""

HEADERS=(-H "Authorization: Bearer $ACCESS")
if [[ -n "$ACCOUNT_ID" ]]; then
    HEADERS+=(-H "ChatGPT-Account-Id: $ACCOUNT_ID")
fi

RESPONSE=$(curl -s "https://chatgpt.com/backend-api/wham/usage" "${HEADERS[@]}")

if echo "$RESPONSE" | jq -e '.detail' > /dev/null 2>&1; then
    echo "Error: $(echo "$RESPONSE" | jq -r '.detail')"
    exit 1
fi

echo "$RESPONSE" | jq '
{
    "plan": .plan_type,
    "primary_used": (.rate_limit.primary_window.used_percent | tostring + "%"),
    "primary_reset_seconds": .rate_limit.primary_window.reset_after_seconds,
    "secondary_used": (.rate_limit.secondary_window.used_percent | tostring + "%"),
    "secondary_reset_seconds": .rate_limit.secondary_window.reset_after_seconds,
    "credits_balance": .credits.balance,
    "credits_unlimited": .credits.unlimited
}'
