#!/bin/bash
# Query Antigravity Local (Language Server) usage
# Requires: Antigravity app running with language_server process
# Models: Claude, antigravity-gemini-3-flash, antigravity-gemini-3-pro

set -e

PROCESS_NAME="language_server_macos"

detect_process_info() {
    local line
    line=$(ps -ax -o pid=,command= | grep -i "$PROCESS_NAME" | grep -i "antigravity" | grep -v grep | head -1)
    
    if [[ -z "$line" ]]; then
        echo "Error: Antigravity language server not running"
        echo "Launch Antigravity IDE and retry"
        exit 1
    fi
    
    PID=$(echo "$line" | awk '{print $1}')
    COMMAND=$(echo "$line" | cut -d' ' -f2-)
    
    CSRF_TOKEN=$(echo "$COMMAND" | grep -oE '\-\-csrf_token[= ]+[^ ]+' | sed 's/--csrf_token[= ]*//')
    
    if [[ -z "$CSRF_TOKEN" ]]; then
        echo "Error: CSRF token not found in process args"
        exit 1
    fi
}

detect_ports() {
    PORTS=$(lsof -nP -iTCP -sTCP:LISTEN -a -p "$PID" 2>/dev/null | grep -oE ':[0-9]+' | sed 's/://' | sort -u)
    
    if [[ -z "$PORTS" ]]; then
        echo "Error: No listening ports found for PID $PID"
        exit 1
    fi
}

make_request() {
    local port=$1
    local scheme=$2
    
    local body='{"metadata":{"ideName":"antigravity","extensionName":"antigravity","ideVersion":"unknown","locale":"en"}}'
    
    curl -s -k -X POST "${scheme}://127.0.0.1:${port}/exa.language_server_pb.LanguageServerService/GetUserStatus" \
        -H "Content-Type: application/json" \
        -H "Connect-Protocol-Version: 1" \
        -H "X-Codeium-Csrf-Token: $CSRF_TOKEN" \
        -d "$body" \
        --connect-timeout 5 \
        --max-time 10
}

echo "=== Antigravity Local (Language Server) Usage ==="
echo ""

detect_process_info
echo "PID: $PID"
echo ""

detect_ports

RESPONSE=""
for port in $PORTS; do
    RESPONSE=$(make_request "$port" "https" 2>/dev/null) && break
    RESPONSE=$(make_request "$port" "http" 2>/dev/null) && break
done

if [[ -z "$RESPONSE" ]]; then
    echo "Error: Failed to connect to any port"
    exit 1
fi

if echo "$RESPONSE" | jq -e '.code' > /dev/null 2>&1; then
    CODE=$(echo "$RESPONSE" | jq -r '.code // "OK"')
    if [[ "$CODE" != "0" && "$CODE" != "OK" && "$CODE" != "ok" ]]; then
        echo "Error: API returned code $CODE"
        echo "$RESPONSE" | jq .
        exit 1
    fi
fi

echo "$RESPONSE" | jq '
{
    "email": .userStatus.email,
    "plan": (.userStatus.userTier.name // .userStatus.planStatus.planInfo.planDisplayName // "unknown"),
    "models": [
        .userStatus.cascadeModelConfigData.clientModelConfigs[]? | 
        select(.quotaInfo) |
        {
            "label": .label,
            "model": .modelOrAlias.model,
            "remaining": ((.quotaInfo.remainingFraction // 1) * 100 | floor | tostring + "%"),
            "reset": .quotaInfo.resetTime
        }
    ]
}'
