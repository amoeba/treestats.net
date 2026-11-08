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
addition to the character. It must be an integer between 0 and 100000.

Unknown fields are ignored, not rejected, so extra metadata (including Mongo's
`_id`) is harmless. Known fields are type-checked — integers must be integers or
numeric strings, and object/array fields must have the expected shape — and a
payload with a bad known field returns `400` with a message naming it.

## Example payloads

Only `name` and `server` are required. This is the smallest useful upload:

<!-- example:minimal -->
```json
{
  "name": "Minimal Example",
  "server": "Example Server"
}
```

Every accepted field, with the shapes and types they expect. `server` must match
the server the token was issued for:

<!-- example:maximal -->
```json
{
  "name": "Maximal Example",
  "server": "Example Server",
  "race": 1,
  "gender": 1,
  "level": 275,
  "rank": 10,
  "followers": 42,
  "deaths": 3,
  "birth": "01/15/2000 08:30:00 PM",
  "total_xp": 1234567890,
  "unassigned_xp": 0,
  "skill_credits": 12,
  "luminance_earned": 5000,
  "luminance_total": 7500,
  "properties": {
    "times_enlightened": 2,
    "augmentations": {
      "critical_frequency": 5
    }
  },
  "attribs": {
    "strength": {"creation": 100, "base": 100, "buffed": 100},
    "endurance": {"creation": 100, "base": 100, "buffed": 100},
    "coordination": {"creation": 100, "base": 100, "buffed": 100},
    "quickness": {"creation": 100, "base": 100, "buffed": 100},
    "focus": {"creation": 100, "base": 100, "buffed": 100},
    "self": {"creation": 100, "base": 100, "buffed": 100}
  },
  "vitals": {
    "health": {"creation": 100, "base": 100, "buffed": 100},
    "stamina": {"creation": 100, "base": 100, "buffed": 100},
    "mana": {"creation": 100, "base": 100, "buffed": 100}
  },
  "skills": {
    "alchemy": {"training": "Specialized", "base": 500, "buffed": 500}
  },
  "allegiance_name": "Example Allegiance",
  "monarch": {"name": "Example Monarch", "race": 1, "gender": 1, "rank": 10},
  "patron": {"name": "Example Patron", "race": 1, "gender": 1, "rank": 9},
  "vassals": [
    {"name": "Example Vassal", "race": 1, "gender": 1, "rank": 9}
  ],
  "version": 1,
  "current_title": 0,
  "titles": [1, 2, 3],
  "account_name": "example-account",
  "location": "Holtburg",
  "server_population": 123
}
```

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
