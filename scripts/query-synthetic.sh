#!/bin/bash
# Query Synthetic usage via OpenCode auth
# Token: ~/.local/share/opencode/auth.json (synthetic.key)
# API: https://api.synthetic.new/v2/quotas

set -e

AUTH_FILE="$HOME/.local/share/opencode/auth.json"

if [[ ! -f "$AUTH_FILE" ]]; then
    echo "Error: OpenCode auth file not found at $AUTH_FILE"
    exit 1
fi

API_KEY=$(jq -r '.synthetic.key // empty' "$AUTH_FILE")

if [[ -z "$API_KEY" ]]; then
    echo "Error: No Synthetic API key found in auth file (synthetic.key)"
    exit 1
fi

echo "=== Synthetic Usage ==="
echo ""

RESPONSE=$(curl -s "https://api.synthetic.new/v2/quotas" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json")

# Check for errors
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "Error: $(echo "$RESPONSE" | jq -r '.error.message // .error')"
    exit 1
fi

# Helper function to calculate time until reset
calculate_time_left() {
    local reset_time="$1"
    local now=$(date +%s)
    
    # Try to parse ISO8601 format with fractional seconds
    local reset_ts=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${reset_time%%.*}" +%s 2>/dev/null || echo 0)
    
    if [[ "$reset_ts" -eq 0 ]]; then
        echo "unknown"
        return
    fi
    
    local diff=$((reset_ts - now))
    if [[ "$diff" -le 0 ]]; then
        echo "now"
        return
    fi
    
    local days=$((diff / 86400))
    local hours=$(((diff % 86400) / 3600))
    local mins=$(((diff % 3600) / 60))
    
    if [[ "$days" -gt 0 ]]; then
        echo "${days}d ${hours}h ${mins}m"
    elif [[ "$hours" -gt 0 ]]; then
        echo "${hours}h ${mins}m"
    else
        echo "${mins}m"
    fi
}

# Check if response has subscription data
HAS_SUBSCRIPTION=$(echo "$RESPONSE" | jq 'has("subscription")')

if [[ "$HAS_SUBSCRIPTION" != "true" ]]; then
    echo "===[ Status ]==="
    echo ""
    echo "No active subscription found."
    echo ""
    echo "You are likely on usage-based pricing."
    echo "Visit https://synthetic.new/pricing to view your usage."
    echo ""
    
    # Raw JSON output option
    if [[ "$1" == "--json" ]]; then
        echo "===[ Raw JSON Response ]==="
        echo ""
        echo "$RESPONSE" | jq .
    fi
    
    exit 0
fi

# Parse subscription data
LIMIT=$(echo "$RESPONSE" | jq -r '.subscription.limit // "null"')
REQUESTS=$(echo "$RESPONSE" | jq -r '.subscription.requests // "null"')
RENEWS_AT=$(echo "$RESPONSE" | jq -r '.subscription.renewsAt // "null"')

echo "===[ Subscription Information ]==="
echo ""
echo "subscription.limit:       $LIMIT"
echo "subscription.requests:    $REQUESTS"
echo "subscription.renewsAt:    $RENEWS_AT"
echo ""

# Calculate usage statistics
if [[ "$LIMIT" != "null" && "$REQUESTS" != "null" ]]; then
    # Handle decimal requests (API returns values like 35.6)
    REMAINING=$(echo "scale=1; $LIMIT - $REQUESTS" | bc)
    USAGE_PCT=$(echo "scale=1; $REQUESTS * 100 / $LIMIT" | bc)
    REMAINING_PCT=$(echo "scale=1; 100 - $USAGE_PCT" | bc)
    
    echo "===[ Calculated Metrics ]==="
    echo ""
    echo "Used:                     $REQUESTS / $LIMIT"
    echo "Remaining:                $REMAINING"
    echo "Usage Percentage:         ${USAGE_PCT}%"
    echo "Remaining Percentage:     ${REMAINING_PCT}%"
    
    if [[ "$RENEWS_AT" != "null" ]]; then
        TIME_LEFT=$(calculate_time_left "$RENEWS_AT")
        echo "Resets in:                $TIME_LEFT"
    fi
    echo ""
fi

echo "===[ Summary ]==="
echo ""

if [[ "$LIMIT" != "null" && "$REQUESTS" != "null" ]]; then
    USAGE_PCT=$(echo "scale=0; $REQUESTS * 100 / $LIMIT" | bc)
    REMAINING_PCT=$((100 - USAGE_PCT))
    
    if [[ "$RENEWS_AT" != "null" ]]; then
        TIME_LEFT=$(calculate_time_left "$RENEWS_AT")
        printf "5h Limit         %3d%% used    (resets in %s)\n" "$USAGE_PCT" "$TIME_LEFT"
    else
        printf "5h Limit         %3d%% used\n" "$USAGE_PCT"
    fi
fi

echo ""

# Raw JSON output option
if [[ "$1" == "--json" ]]; then
    echo "===[ Raw JSON Response ]==="
    echo ""
    echo "$RESPONSE" | jq .
fi
