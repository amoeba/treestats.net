# Asheron's Call Server Information

This is the TreeStats proposal for a small, standard document that any Asheron's Call server can serve so tools can discover server metadata without per-server integrations.

It is a follow-on to [treestats.net#278](https://github.com/amoeba/treestats.net/issues/278) and is related to [ACEmulator/ACE#718](https://github.com/ACEmulator/ACE/issues/718).

## Location

Serve the document at the root of the server's public game endpoint:

```
http(s)://<server-host>:<game-port>/
```

For example, `http://play.example.net:9000/`. The host and port should match the server's entry in the [community server list](https://github.com/acresources/serverslist).

There is no required path component. HTTP and HTTPS are both acceptable; HTTPS is preferred when available. TreeStats tries HTTP at the root first and falls back to HTTPS if the HTTP request fails. It does not follow redirects, but an HTTP-to-HTTPS redirect still triggers the HTTPS fallback. To force HTTPS, serve only HTTPS at the root or give TreeStats an explicit HTTPS URL.

## Document

The response must be a JSON object. All fields are optional.

```json
{
  "schema": "https://treestats.net/schemas/asherons-call-server/v1/schema.json",
  "version": 1,
  "updated_at": "2026-11-07T18:00:00Z",
  "name": "Example World",
  "population": {
    "count": 42,
    "updated_at": "2026-11-07T18:00:00Z"
  },
  "emulator": {
    "name": "ACE",
    "version": "1.2.3"
  }
}
```

The canonical schema is published at <https://treestats.net/schemas/asherons-call-server/v1/schema.json>.

Consumers must ignore unknown fields. All timestamps are RFC3339 strings with an explicit UTC offset (`Z` or `±HH:MM`).

### Fields

- `schema` (optional, string): URL of the schema for this document.
- `version` (optional, integer): Document format version. This document describes version `1`.
- `name` (optional, string): The server or world name as configured by the operator.
- `updated_at` (optional, string): When the document was generated. Used as the measurement time when `population.updated_at` is absent.
- `population` (optional, object): Current in-world player population. All nested fields are optional.
  - `count` (optional, integer): Number of connected, in-world player characters, including bots, multiboxed characters, staff, and test characters. Count characters, not unique people or accounts. A measured empty world is `0`; when absent, no population count is recorded. Inability to measure must be an error or an omitted `count`/`population`, not a fabricated zero.
  - `updated_at` (optional, string): When the population was measured. Falls back to the document's `updated_at` when absent. Advance this for each new measurement even if the count did not change. Re-serving an old snapshot must not renew it.
- `emulator` (optional, object): Server emulator software. All nested fields are optional.
  - `name` (optional, string): e.g. `ACE` or `GDLE`.
  - `version` (optional, string): e.g. `1.2.3`.

If neither `population.updated_at` nor the top-level `updated_at` is present, TreeStats stores the last result but does not create a historical population observation.

## Reference implementation

The ACE mod `ACE.Mods.Treestats` serves a document of this shape from the game endpoint. TreeStats polls opted-in servers at the root `/`. Registered servers that serve the document elsewhere can be listed with an explicit URL in `config/polling_targets.yml`.
