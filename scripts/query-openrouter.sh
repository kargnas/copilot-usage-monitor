#!/bin/bash
# Query OpenRouter usage and credits
# Token: ~/.local/share/opencode/auth.json

set -e

AUTH_FILE="$HOME/.local/share/opencode/auth.json"

if [[ ! -f "$AUTH_FILE" ]]; then
    echo "Error: OpenCode auth file not found at $AUTH_FILE"
    exit 1
fi

API_KEY=$(jq -r '.openrouter.key // empty' "$AUTH_FILE")

if [[ -z "$API_KEY" ]]; then
    echo "Error: No OpenRouter API key found in auth file"
    exit 1
fi

echo "=== OpenRouter Usage ==="
echo ""

# Get credits summary
echo "--- Credits ---"
curl -s "https://openrouter.ai/api/v1/credits" \
    -H "Authorization: Bearer $API_KEY" | jq '{
    total_credits: .data.total_credits,
    total_usage: .data.total_usage,
    remaining: (.data.total_credits - .data.total_usage)
}'

echo ""
echo "--- Key Info ---"
curl -s "https://openrouter.ai/api/v1/key" \
    -H "Authorization: Bearer $API_KEY" | jq '{
    label: .data.label,
    limit: .data.limit,
    limit_reset: .data.limit_reset,
    limit_remaining: .data.limit_remaining,
    usage_daily: .data.usage_daily,
    usage_weekly: .data.usage_weekly,
    usage_monthly: .data.usage_monthly,
    is_free_tier: .data.is_free_tier
}'

echo ""
echo "--- Activity (Last 30 Days Summary) ---"
ACTIVITY=$(curl -s "https://openrouter.ai/api/v1/activity" \
    -H "Authorization: Bearer $API_KEY")

# Check if there's activity data
if echo "$ACTIVITY" | jq -e '.data | length > 0' > /dev/null 2>&1; then
    echo "$ACTIVITY" | jq '
    .data | 
    group_by(.date) | 
    map({
        date: .[0].date,
        total_requests: length,
        models: [.[].model] | unique
    }) |
    sort_by(.date) |
    reverse |
    .[:14]'
else
    echo "No activity data available (API may not track individual requests for this key)"
fi
