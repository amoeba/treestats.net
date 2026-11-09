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

The body is the same JSON the Decal plugin sends. Its canonical shape is
described by the [character upload schema](https://treestats.net/schemas/character/v2/schema.json).
The payload must be a JSON object, its `server` field must match the server the
token was issued for, and it may be at most 1 MiB. Direct uploads are
authenticated by the token instead of the plugin's `TREESTATS_SECRET` body check.

If the payload contains `server_population`, a player count sample is recorded in
addition to the character. It is best effort: only a positive integer is
recorded, and anything else (0, negative, non-numeric) is ignored so the
character upload still succeeds.

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

`race` and `gender` may be names or numeric IDs, including in `monarch`,
`patron`, and `vassals`. `version` may be a string or integer; the example uses
the string form.

<!-- example:maximal -->
```json
{
  "name": "Maximal Example",
  "server": "Example Server",
  "account_name": "example-account",
  "version": "2",
  "race": "Aluvian",
  "gender": "Male",
  "level": 275,
  "allegiance_name": "Example Allegiance",
  "rank": 10,
  "followers": 42,
  "server_population": 123,
  "deaths": 3,
  "birth": "01/15/2000 08:30:00 PM",
  "total_xp": 1234567890,
  "unassigned_xp": 0,
  "skill_credits": 12,
  "luminance_earned": 5000,
  "luminance_total": 7500,
  "attribs": {
    "strength": {"name": "Strength", "base": 100, "creation": 100},
    "endurance": {"name": "Endurance", "base": 100, "creation": 100},
    "quickness": {"name": "Quickness", "base": 100, "creation": 100},
    "coordination": {"name": "Coordination", "base": 100, "creation": 100},
    "focus": {"name": "Focus", "base": 100, "creation": 100},
    "self": {"name": "Self", "base": 100, "creation": 100}
  },
  "vitals": {
    "health": {"name": "Health", "base": 100},
    "stamina": {"name": "Stamina", "base": 100},
    "mana": {"name": "Mana", "base": 100}
  },
  "skills": {
    "alchemy": {"name": "alchemy", "base": 500, "training": "Specialized"}
  },
  "monarch": {"name": "Example Monarch", "race": 1, "gender": 1, "rank": 10},
  "patron": {"name": "Example Patron", "race": 1, "gender": 1, "rank": 9},
  "vassals": [
    {"name": "Example Vassal", "race": 1, "gender": 1, "rank": 9}
  ],
  "current_title": 0,
  "titles": [1, 2, 3],
  "location": "Holtburg",
  "properties": {
    "354": 7,
    "355": 12
  }
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
