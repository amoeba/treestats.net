# Asheron's Call Server Information

This is the TreeStats proposal for a small, standard document that any Asheron's Call server can serve so tools can discover server metadata without per-server integrations.

It is a follow-on to [treestats.net#278](https://github.com/amoeba/treestats.net/issues/278) and is related to [ACEmulator/ACE#718](https://github.com/ACEmulator/ACE/issues/718).

## Quick start for server operators

TreeStats only polls servers that have opted in, but you can make the document available first.

1. **Serve the JSON at the root of your public game endpoint.**

   ```text
   GET http://<server-host>:<game-port>/
   ```

   For example, `http://play.example.net:9000/` should return the JSON document, not an HTML page. Use the same host and port you publish in the [community server list](https://github.com/acresources/serverslist).

2. **If your game server cannot serve HTTP on that host and port, use a separate web host.**

   Host the same JSON at any public HTTP or HTTPS URL, for example:

   ```text
   https://status.example.net/example-world.json
   ```

   Give TreeStats that exact URL. Any static web host works; the document does not need to be served by the game server. The URL must be publicly reachable, must not require authentication, and must not redirect.

3. **Verify it from outside your network.**

   ```sh
   curl -i http://play.example.net:9000/
   ```

   You want an HTTP 200 response with a JSON body. HTTP and HTTPS are both accepted; HTTPS is preferred when available.

4. **Keep the measurement time current.**

   Update `population.updated_at` every time you measure the population, even if the count did not change. Do not serve an old cached snapshot with an old timestamp; TreeStats rejects future timestamps and will not accept a re-served old snapshot as a new observation.

5. **Ask TreeStats to enable polling.**

   Your server must appear in `data/servers.rb`, and TreeStats must enable it in `config/polling_targets.yml`. If you are not the TreeStats operator, open an [issue](https://github.com/amoeba/treestats.net/issues) or pull request with your server name and document URL.

6. **ACE servers.**

   The intended ACE reference implementation is [`ACEmulator/ACE.Mods.TreeStats`](https://github.com/ACEmulator/ACE.Mods.TreeStats). It serves this document from the game endpoint; see that project for current installation and configuration instructions.

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
    "server_version": "1.78.4832.20261104180934-master-402a24e",
    "database_version": "v0.9.296",
    "dat_iterations": {
      "client_portal.dat": 2072,
      "client_cell_1.dat": 982,
      "client_local_english.dat": 994,
      "client_hires.dat": 0
    }
  }
}
```

The canonical schema is published at <https://treestats.net/schemas/asherons-call-server/v1/schema.json>.

Consumers must ignore unknown fields. All timestamps are RFC3339 strings with an explicit UTC offset (`Z` or `±HH:MM`).

### Fields

- `schema` (optional, string): URL of the schema for this document.
- `version` (optional, integer): Document format version. This document describes version `1`. Consumers should reject versions they do not support; TreeStats rejects versions other than `1`.
- `name` (optional, string): The server or world name as configured by the operator.
- `updated_at` (optional, string): When the document was generated. Used as the measurement time when `population.updated_at` is absent.
- `population` (optional, object): Current in-world player population. All nested fields are optional.
  - `count` (optional, integer): Number of connected, in-world player characters, including bots, multiboxed characters, staff, and test characters. Count characters, not unique people or accounts. A measured empty world is `0`; when absent, no population count is recorded. Inability to measure must be an error or an omitted `count`/`population`, not a fabricated zero.
  - `updated_at` (optional, string): When the population was measured. Falls back to the document's `updated_at` when absent. Advance this for each new measurement even if the count did not change. Re-serving an old snapshot must not renew it.
- `emulator` (optional, object): Server emulator software. All nested fields are optional.
  - `name` (optional, string): e.g. `ACE` or `GDLE`.
  - `server_version` (optional, string): Emulator server build version, e.g. `1.78.4832.20261104180934-master-402a24e`.
  - `database_version` (optional, string): Emulator database version, e.g. `v0.9.296`.
  - `dat_iterations` (optional, object): Iteration counts keyed by DAT filename. Values are nonnegative integers; additional DAT names are allowed.

If neither `population.updated_at` nor the top-level `updated_at` is present, TreeStats stores the last result but does not create a historical population observation.

A measurement timestamp (the population's `updated_at`, or the document's `updated_at` when used as the fallback) must not be in the future relative to when the document is served. TreeStats rejects future measurement times.

## Reference implementation

The ACE mod [`ACE.Mods.TreeStats`](https://github.com/ACEmulator/ACE.Mods.TreeStats) is the intended reference implementation and serves a document of this shape from the game endpoint. TreeStats polls opted-in servers at the root `/`. Registered servers that serve the document elsewhere can be listed with an explicit URL in `config/polling_targets.yml`.
