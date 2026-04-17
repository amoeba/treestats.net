#!/usr/bin/env bash
#
# Test the POST /characters bulk upload endpoint.
#
# Usage:
#   ./scripts/test_bulk_upload.sh [COUNT] [SERVER]
#
# Environment:
#   BULK_UPLOAD_SECRET  Shared HMAC secret (matches server's BULK_UPLOAD_SECRET)
#   HOST                Host and port (default: localhost:9292)
#
# Examples:
#   ./scripts/test_bulk_upload.sh
#   ./scripts/test_bulk_upload.sh 100 Coldeve
#   BULK_UPLOAD_SECRET=mysecret HOST=localhost:9292 ./scripts/test_bulk_upload.sh 500

set -euo pipefail

COUNT="${1:-10}"
SERVER="${2:-Coldeve}"
HOST="${HOST:-localhost:9292}"
SECRET="${BULK_UPLOAD_SECRET:-}"

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

# Compute HMAC-SHA256 signature
if [ -n "\$SECRET" ]; then
  DIGEST=$(printf '%s' "\$BODY" | openssl dgst -sha256 -hmac "\$SECRET" | awk '{print \$NF}')
  SIGNATURE="sha256=\${DIGEST}"
else
  echo "Warning: BULK_UPLOAD_SECRET not set, sending without a valid signature (will be accepted if server secret is also unset)"
  SIGNATURE="sha256=nosecret"
fi

RECORD_COUNT=$(echo "\$BODY" | wc -l | tr -d ' ')
echo "Uploading \${RECORD_COUNT} records to http://\${HOST}/characters ..."

curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X POST \
  -H "Content-Type: application/x-ndjson" \
  -H "X-TreeStats-Upload-Signature: \${SIGNATURE}" \
  --data-binary "\$BODY" \
  "http://\${HOST}/characters"
