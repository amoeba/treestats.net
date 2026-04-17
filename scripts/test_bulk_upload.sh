#!/usr/bin/env bash
#
# Test the POST /characters bulk upload endpoint.
#
# Usage:
#   ./scripts/test_bulk_upload.sh [COUNT] [SERVER]
#
# Environment:
#   TS_API_KEY  API key from POST /account/key (format: ts_<account_id><secret>)
#   HOST        Host and port (default: localhost:9292)
#
# Examples:
#   ./scripts/test_bulk_upload.sh
#   ./scripts/test_bulk_upload.sh 100 Coldeve
#   TS_API_KEY=ts_... HOST=localhost:9292 ./scripts/test_bulk_upload.sh 500
#
# To generate a key:
#   curl -s -X POST http://localhost:9292/account/key \
#     -H 'Content-Type: application/json' \
#     -d '{"name":"myaccount","password":"mypassword"}'

set -euo pipefail

COUNT="${1:-10}"
SERVER="${2:-Coldeve}"
HOST="${HOST:-localhost:9292}"
API_KEY="${TS_API_KEY:-}"

# Generate synthetic NDJSON using Ruby (already a project dependency)
BODY=$(ruby -r json -e "
  count  = ${COUNT}
  server = '${SERVER}'
  races  = %w[1 2 3 4 5 6 7 8 9]
  count.times.map do |i|
    {
      'name'            => \"BulkTest#{i}\",
      'server'          => server,
      'level'           => rand(1..275),
      'race'            => races.sample,
      'gender'          => %w[1 2].sample,
      'total_xp'        => rand(0..10_000_000_000),
      'unassigned_xp'   => rand(0..1_000_000),
    }.to_json
  end.join(\"\n\")
")

if [ -z "$API_KEY" ]; then
  echo "Error: TS_API_KEY must be set."
  echo "Generate a key with: curl -s -X POST http://${HOST}/account/key -H 'Content-Type: application/json' -d '{\"name\":\"myaccount\",\"password\":\"mypassword\"}'"
  exit 1
fi

DIGEST=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$API_KEY" | awk '{print $NF}')
SIGNATURE="sha256=${DIGEST}"

RECORD_COUNT=$(echo "$BODY" | wc -l | tr -d ' ')
echo "Uploading ${RECORD_COUNT} records to http://${HOST}/characters ..."

curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X POST \
  -H "Content-Type: application/x-ndjson" \
  -H "X-TreeStats-Upload-Signature: ${SIGNATURE}" \
  -H "X-TreeStats-Api-Key: ${API_KEY}" \
  --data-binary "$BODY" \
  "http://${HOST}/characters"
