# Direct Uploads

Servers can push character updates straight to TreeStats instead of relying on
the [Decal plugin](https://github.com/amoeba/treestats).

## Getting a token

1. Sign in at `/admin/login` and open **Administration** (`/admin`).
2. Under **Server upload tokens**, pick the server and choose **Generate token**.
3. Copy the token from the page that follows. It is shown once.

Tokens are scoped to one server. Reissuing replaces the token and immediately
invalidates the previous one; revoking deletes it. Treat the token as a secret
and send it only over HTTPS.

## Uploading

```
POST /characters
X-TreeStats-Server-Token: ts_...
Content-Type: application/json
```

The body is the same JSON the Decal plugin sends. The payload must be a JSON
object, its `server` field must match the server the token was issued for, and it
may be at most 1 MiB. Direct uploads are authenticated by the token instead of
the plugin's `TREESTATS_SECRET` body check.

If the payload contains `server_population`, a player count sample is recorded in
addition to the character.

## Responses

| Status | Meaning |
|---|---|
| 200 | Character accepted |
| 400 | Body is not valid JSON or not a JSON object, or the character is invalid |
| 401 | Token header missing |
| 403 | Token invalid or revoked, or the server is a retail server |
| 413 | Body larger than 1 MiB |
| 429 | Rate limit exceeded |

## Rate limits

Each token allows 1,000 requests per hour. Responses include `RateLimit-Limit`,
`RateLimit-Remaining`, and `RateLimit-Reset` (seconds until the window resets);
`X-RateLimit-Reset` carries the same reset time as a Unix timestamp.
