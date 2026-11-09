# Direct Uploads

Servers can push character updates directly to TreeStats instead of relying on
the [Decal plugin](https://github.com/amoeba/treestats). Direct uploads require a special, admin-issued token that is intended for server operators and is restricted to uploading characters on a single server.

## Uploading

Once you have a token, send a POST to `/characters` like this:

```
POST /characters
X-TreeStats-Server-Token: ts_...
Content-Type: application/json
```

## Example Payloads

Only `name` and `server` are required. This is the smallest useful upload:

<!-- example:minimal -->
```json
{
  "name": "Minimal Example",
  "server": "Example Server"
}
```

A complete example:

<!-- example:maximal -->
```json
{
  "name": "Maximal Example",
  "server": "Example Server",
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

Note: Unlike at the root of the document, in allegiance records, race and gender are integers instead of strings and correspond to the following values:

Race

- `1` — Aluvian
- `2` — Gharu'ndim
- `3` — Sho
- `4` — Viamontian
- `5` — Shadowbound
- `6` — Gearknight
- `7` — Tumerok
- `8` — Lugian
- `9` — Empyrean
- `10` — Penumbraen
- `11` — Undead
- `12` — Olthoi
- `13` — OlthoiAcid

Gender

- `1` — Male
- `2` — Female

## Schema

A JSON schema document is provided at https://treestats.net/schemas/character/v2/schema.json. Uploads aren't validated against this schema but it may help when creating JSON documents.

## Responses

| Status | Meaning |
|---|---|
| 200 | Character accepted |
| 400 | Body is not valid JSON or not a JSON object, contains a plugin-only account field, or the character is invalid |
| 401 | Token header missing |
| 403 | Token invalid or revoked, or the server is a retail server |
| 413 | Body larger than 1 MiB |
| 429 | Rate limit exceeded |

## Rate limits

Each token allows 1,000 requests per hour. Responses include `RateLimit-Limit`,
`RateLimit-Remaining`, and `RateLimit-Reset` (seconds until the window resets);
`X-RateLimit-Reset` carries the same reset time as a Unix timestamp.
