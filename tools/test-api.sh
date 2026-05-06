#!/usr/bin/env bash
# End-to-end smoke test for the PixelHop API.
# Usage:
#   ./tools/test-api.sh                   # against local http://localhost:3000
#   API=https://applewatch-mario-api.72.62.0.34.sslip.io ./tools/test-api.sh
set -euo pipefail

API="${API:-http://localhost:3000}"
echo "==> Testing $API"

DEVICE_ID=$(uuidgen | tr 'A-Z' 'a-z')
NICK="tester$(date +%s | tail -c 6)"

green() { printf "\033[32m✓\033[0m %s\n" "$*"; }
red()   { printf "\033[31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# 1. health
H=$(curl -fsS "$API/v1/health")
echo "$H" | jq . > /dev/null || red "health: not json"
[[ $(echo "$H" | jq -r .ok) == "true" ]] || red "health: ok != true"
green "health"

# 2. register device
REG=$(curl -fsS -X POST "$API/v1/devices" \
  -H "Content-Type: application/json" \
  -d "$(jq -nc --arg id "$DEVICE_ID" --arg n "$NICK" '{device_id:$id, nickname:$n}')")
SECRET=$(echo "$REG" | jq -r .secret)
[[ -n "$SECRET" && "$SECRET" != "null" ]] || red "register: no secret"
green "register device $DEVICE_ID nickname=$NICK"

# 3. nickname uniqueness — registering again must fail
HTTP=$(curl -s -o /tmp/dup.json -w "%{http_code}" -X POST "$API/v1/devices" \
  -H "Content-Type: application/json" \
  -d "$(jq -nc --arg id "$DEVICE_ID" --arg n "$NICK" '{device_id:$id, nickname:$n}')")
[[ "$HTTP" == "409" ]] || red "register-duplicate: expected 409 got $HTTP"
green "duplicate registration rejected with 409"

# helper: sign + submit
sign_and_post() {
  local path="$1" body="$2" override_sig="${3:-}"
  local ts nonce method url sig
  ts=$(date +%s)
  nonce=$(openssl rand -hex 16)
  method=POST
  local sig_input
  printf -v sig_input '%s\n%s\n%s\n%s\n%s' "$method" "$path" "$ts" "$nonce" "$body"
  sig=$(printf '%s' "$sig_input" | openssl dgst -sha256 -hmac "$SECRET" -hex | awk '{print $NF}')
  if [[ -n "$override_sig" ]]; then sig="$override_sig"; fi
  curl -s -o /tmp/post.json -w "%{http_code}" -X "$method" "$API$path" \
    -H "Content-Type: application/json" \
    -H "X-Device-Id: $DEVICE_ID" \
    -H "X-Timestamp: $ts" \
    -H "X-Nonce: $nonce" \
    -H "X-Sig: $sig" \
    --data-binary "$body"
}

# 4. submit a valid score
BODY='{"level":"1-1","score":4500,"time_ms":40000,"coins":12,"world_completed":false}'
HTTP=$(sign_and_post "/v1/scores" "$BODY")
[[ "$HTTP" == "201" ]] || { cat /tmp/post.json; red "submit-score: expected 201 got $HTTP"; }
green "submit valid score 1-1: 4500"

# 5. tampered signature must fail
HTTP=$(sign_and_post "/v1/scores" "$BODY" "deadbeef$(openssl rand -hex 30)")
[[ "$HTTP" == "401" ]] || red "tampered-sig: expected 401 got $HTTP"
green "tampered signature rejected with 401"

# 6. nonce replay — re-use the *exact* request must be detected
TS=$(date +%s)
NONCE=$(openssl rand -hex 16)
SIG_INPUT=$(printf '%s\n%s\n%s\n%s\n%s' "POST" "/v1/scores" "$TS" "$NONCE" "$BODY")
SIG=$(printf '%s' "$SIG_INPUT" | openssl dgst -sha256 -hmac "$SECRET" -hex | awk '{print $NF}')
H1=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/v1/scores" \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE_ID" -H "X-Timestamp: $TS" -H "X-Nonce: $NONCE" -H "X-Sig: $SIG" \
  --data-binary "$BODY")
H2=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/v1/scores" \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE_ID" -H "X-Timestamp: $TS" -H "X-Nonce: $NONCE" -H "X-Sig: $SIG" \
  --data-binary "$BODY")
[[ "$H1" == "201" && "$H2" == "401" ]] || red "replay: expected 201 then 401, got $H1 $H2"
green "nonce replay rejected"

# 7. leaderboard read
LB=$(curl -fsS "$API/v1/leaderboard/1-1")
COUNT=$(echo "$LB" | jq '.top | length')
[[ "$COUNT" -ge 1 ]] || red "leaderboard: empty"
green "leaderboard 1-1 has $COUNT entries; top score=$(echo "$LB" | jq '.top[0].score')"

echo
green "ALL CHECKS PASSED against $API"
