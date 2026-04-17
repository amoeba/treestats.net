# Bulk Character Upload

## API Keys

Each account has one API key. Retrieve or create it:

```
POST /account/key
Content-Type: application/json

{"name": "account_name", "password": "account_password"}
```

Response:

```json
{"key": "ts_<account_id_hex><32_random_bytes_hex>"}
```

## Uploading Characters

```
POST /characters
X-Treestats-Api-Key: <api_key>
X-Treestats-Upload-Signature: sha256=<hmac_hex>
Content-Type: application/json  (or application/x-ndjson)
```

The body is either a JSON array or NDJSON (one object per line). The signature is HMAC-SHA256 over the raw request body using the API key secret as the key.

Responses:

| Status | Meaning |
|--------|---------|
| 202 | Accepted and queued |
| 403 | Invalid or missing signature |
| 429 | Per-IP rate limit exceeded |
| 503 | Too many jobs in flight, retry later |

## Processing

Jobs run asynchronously via Sidekiq. Each record is upserted into `Character`. The job:

- Skips characters on retail servers.
- Skips records with a malformed patron name (`"??"`).
- Extracts `server_population` into `PlayerCount` if present.
- Strips the `key` field before saving.
- Deletes the temp file and decrements the in-flight counter when done (success or failure).

## Configuration

| Env var | Default | Description |
|---------|---------|-------------|
| `BULK_UPLOAD_RATE_LIMIT` | 5 | Max requests per window per IP |
| `BULK_UPLOAD_RATE_WINDOW` | 60 | Rate limit window in seconds |
| `BULK_UPLOAD_MAX_INFLIGHT` | 10 | Max concurrent jobs |
