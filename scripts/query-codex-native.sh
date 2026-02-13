#!/bin/bash
# Query Codex (OpenAI/ChatGPT) usage via Codex CLI native auth
# Token: ~/.codex/auth.json

set -e

AUTH_FILE="$HOME/.codex/auth.json"

if [[ ! -f "$AUTH_FILE" ]]; then
    echo "Error: Codex CLI auth file not found at $AUTH_FILE"
    exit 1
fi

ACCESS=$(jq -r '.tokens.access_token // empty' "$AUTH_FILE")
ACCOUNT_ID=$(jq -r '.tokens.account_id // empty' "$AUTH_FILE")

if [[ -z "$ACCESS" ]]; then
    echo "Error: No access token found in $AUTH_FILE"
    exit 1
fi

echo "=== Codex (OpenAI) Usage ==="
echo ""

# Decode JWT to extract user info (email, plan, etc.)
decode_jwt_payload() {
    local token="$1"
    local payload=$(echo "$token" | cut -d'.' -f2)
    local mod=$((${#payload} % 4))
    if [ $mod -eq 2 ]; then
        payload="${payload}=="
    elif [ $mod -eq 3 ]; then
        payload="${payload}="
    fi
    echo "$payload" | base64 -d 2>/dev/null
}

JWT_PAYLOAD=$(decode_jwt_payload "$ACCESS")
if [[ -n "$JWT_PAYLOAD" ]]; then
    echo "=== Account Info (from JWT) ==="
    echo "$JWT_PAYLOAD" | jq '{
        "email": ."https://api.openai.com/profile".email,
        "email_verified": ."https://api.openai.com/profile".email_verified,
        "plan_type": ."https://api.openai.com/auth".chatgpt_plan_type,
        "user_id": ."https://api.openai.com/auth".chatgpt_user_id,
        "mfa_required": ."https://api.openai.com/mfa".required,
        "token_expires_at": (.exp | todate),
        "token_issued_at": (.iat | todate)
    }'
    echo ""
fi

HEADERS=(-H "Authorization: Bearer $ACCESS")
if [[ -n "$ACCOUNT_ID" ]]; then
    HEADERS+=(-H "ChatGPT-Account-Id: $ACCOUNT_ID")
fi

RESPONSE=$(curl -s "https://chatgpt.com/backend-api/wham/usage" "${HEADERS[@]}")

if echo "$RESPONSE" | jq -e '.detail' > /dev/null 2>&1; then
    echo "Error: $(echo "$RESPONSE" | jq -r '.detail')"
    exit 1
fi

echo "=== RAW Response ==="
echo "$RESPONSE"

echo "=== Usage Stats ==="
echo "$RESPONSE" | jq '
def spark_windows: (.rate_limit | to_entries | map(select(.key | test("spark"; "i"))));
def additional_spark_limits: ((.additional_rate_limits // []) | map(select((.limit_name // "" | test("spark"; "i")) and (.rate_limit != null))));
def spark_window_obj: (
    if (spark_windows | length) > 0
    then {"primary_window": (spark_windows | map(.value)[0]), "secondary_window": null}
    elif (additional_spark_limits | length) > 0
    then (additional_spark_limits[0].rate_limit // null)
    else null
    end
);
def spark_label: (
    if (spark_windows | length) > 0
    then (spark_windows | map(.key)[0] // null)
    elif (additional_spark_limits | length) > 0
    then (additional_spark_limits[0].limit_name // null)
    else null
    end
);
{
    "plan": .plan_type,
    "primary_used": (.rate_limit.primary_window.used_percent | tostring + "%"),
    "primary_reset_seconds": .rate_limit.primary_window.reset_after_seconds,
    "secondary_used": (.rate_limit.secondary_window.used_percent | tostring + "%"),
    "secondary_reset_seconds": .rate_limit.secondary_window.reset_after_seconds,
    "spark_primary_used": ((spark_window_obj.primary_window.used_percent // null) | if . == null then null else tostring + "%" end),
    "spark_primary_reset_seconds": (spark_window_obj.primary_window.reset_after_seconds // null),
    "spark_secondary_used": ((spark_window_obj.secondary_window.used_percent // null) | if . == null then null else tostring + "%" end),
    "spark_secondary_reset_seconds": (spark_window_obj.secondary_window.reset_after_seconds // null),
    "spark_used": ((spark_window_obj.primary_window.used_percent // null) | if . == null then null else tostring + "%" end),
    "spark_window": spark_label,
    "spark_reset_seconds": (spark_window_obj.primary_window.reset_after_seconds // null),
    "credits_balance": .credits.balance,
    "credits_unlimited": .credits.unlimited
}'
