#!/bin/bash
# Query Antigravity (Gemini Cloud Code) usage
# Token: ~/.config/opencode/antigravity-accounts.json
# Antigravity requires token refresh - access tokens expire in 1 hour

set -e

ACCOUNTS_FILE="$HOME/.config/opencode/antigravity-accounts.json"
CLIENT_ID="1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
CLIENT_SECRET="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"

if [[ ! -f "$ACCOUNTS_FILE" ]]; then
    echo "Error: Antigravity accounts file not found at $ACCOUNTS_FILE"
    exit 1
fi

ACTIVE_INDEX=$(jq -r '.activeIndex // 0' "$ACCOUNTS_FILE")
REFRESH=$(jq -r ".accounts[$ACTIVE_INDEX].refreshToken // empty" "$ACCOUNTS_FILE")
EMAIL=$(jq -r ".accounts[$ACTIVE_INDEX].email // \"unknown\"" "$ACCOUNTS_FILE")

if [[ -z "$REFRESH" ]]; then
    echo "Error: No refresh token found for account index $ACTIVE_INDEX"
    exit 1
fi

echo "=== Antigravity (Gemini Cloud Code) Usage ==="
echo "Account: $EMAIL"
echo ""

TOKEN_RESPONSE=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "refresh_token=$REFRESH" \
    -d "grant_type=refresh_token")

ACCESS=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')

if [[ -z "$ACCESS" ]]; then
    echo "Error: Failed to refresh access token"
    echo "$TOKEN_RESPONSE" | jq .
    exit 1
fi

curl -s -X POST "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota" \
    -H "Authorization: Bearer $ACCESS" \
    -H "Content-Type: application/json" \
    -d '{}' | jq '
{
    "quotas": [.buckets[] | {
        "model": .modelId,
        "remaining": ((.remainingFraction * 100 | floor | tostring) + "%"),
        "reset": .resetTime
    }]
}'
