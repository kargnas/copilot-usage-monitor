#!/bin/bash
# Query Claude (Anthropic) usage via OpenCode auth
# Token: ~/.local/share/opencode/auth.json

set -e

AUTH_FILE="$HOME/.local/share/opencode/auth.json"

if [[ ! -f "$AUTH_FILE" ]]; then
    echo "Error: OpenCode auth file not found at $AUTH_FILE"
    exit 1
fi

ACCESS=$(jq -r '.anthropic.access // empty' "$AUTH_FILE")

if [[ -z "$ACCESS" ]]; then
    echo "Error: No Anthropic token found in auth file"
    exit 1
fi

echo "=== Claude (Anthropic) Usage ==="
echo ""

RESPONSE=$(curl -s "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $ACCESS" \
    -H "anthropic-beta: oauth-2025-04-20")

if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "Error: $(echo "$RESPONSE" | jq -r '.error.message // .error')"
    exit 1
fi

echo "$RESPONSE" | jq '
{
    "5h_usage": ((.five_hour.utilization // 0) | tostring + "%"),
    "5h_reset": .five_hour.resets_at,
    "7d_usage": ((.seven_day.utilization // 0) | tostring + "%"),
    "7d_reset": .seven_day.resets_at,
    "7d_sonnet": ((.seven_day_sonnet.utilization // 0) | tostring + "%"),
    "7d_opus": ((.seven_day_opus.utilization // 0) | tostring + "%"),
    "extra_usage_enabled": .extra_usage.is_enabled
}'
