# Data Polling

TreeStats normally stores data sent to it by the [Decal plugin](https://github.com/amoeba/treestats).
This limits the data we have because not everyone runs the plugin.
Additionally, for data like server population counts, even plugin users may not give very fine-grained data because the plugin only sends population data when the player logs into the game world and players don't always relog often.

This documents how TreeStats can poll external HTTP endpoints for data in order to augment plugin-collected data.
At this time, polling records population count observations and stores the last parsed document; this could be extended in the future to handle other historical data.

## Polling Targets

Polling is opt-in. Each server is listed in `./config/polling_targets.yml` by its name from `./data/servers.rb` and declares whether it is enabled:

```yaml
interval: 15m
targets:
  Example Server:
    enabled: true
  Other Server:
    enabled: true
    url: https://status.example.net/data.json
  Not Ready Yet:
    enabled: false
```

When `url` is omitted, TreeStats polls the server's public game endpoint root, trying HTTP first and falling back to HTTPS if the HTTP request fails:

```
http://<server-host>:<game-port>/
https://<server-host>:<game-port>/
```

The document served there is described by the [Asheron's Call Server Information](./asherons-call-server.md) standard.
A `url` overrides the root endpoints and is used as-is, with no fallback. It must be an absolute HTTP or HTTPS URL without credentials, a fragment, or a port outside 1–65535; leading and trailing whitespace is stripped, and a blank `url` is rejected. The server name must match an entry in `./data/servers.rb` even when `url` is set. Disabled entries can stay in the file without being polled.

The `interval` field is global for all targets and defines how often we poll all of them.
`interval` accepts friendly units such as `15m`, `30 mins`, `1hr`, `6 hours`, or `1d`. Minute intervals must divide an hour evenly (1, 2, 3, 4, 5, 6, 10, 12, 15, 20, or 30), and hour intervals must divide a day evenly (1, 2, 3, 4, 6, 8, 12, or 24). The Sidekiq worker fails fast at boot on an unsupported interval or an invalid target configuration. Changing the interval requires restarting the Sidekiq worker so the cron schedule is reloaded.

## Target Response

Targets respond with the standard document:

```json
{
  "updated_at": "2026-11-07T18:00:00Z",
  "population": {
    "count": 42,
    "updated_at": "2026-11-07T18:00:00Z"
  }
}
```

All fields are optional. `population.updated_at` is the measurement time; when it is absent, the document's `updated_at` is used instead. A document without a count, or without either timestamp, is valid: TreeStats stores the last result but creates no historical observation.

- `count` is a nonnegative integer counting connected, in-world player characters, including bots, multiboxed characters, staff, and test characters. Do not count unique people/accounts or exclude operator-defined categories. A measured empty world is `0`; when absent, no observation is recorded. Inability to measure must be an error or an omitted `count`/`population`, not a fabricated zero.
- `updated_at` is when the population was measured, not when the document was served, and is an RFC3339 string with an explicit offset. It falls back to the document's top-level `updated_at` when absent. Advance it for a new measurement even if the count did not change. Re-serving an old snapshot must not renew it.
- The last successfully parsed document is stored per server; its count and timestamps are shown in the admin dashboard. A document with no count is recorded as `empty`; a count without a measurement time is recorded as `no_timestamp`.
- `schema`, `version`, `name`, and `emulator` are stored with the last poll result but are not used for the population observation or to identify the server. Unknown fields are ignored. TreeStats supports document version 1 and rejects higher versions. TreeStats binds the server identity from reviewed configuration; do not rely on identity or provenance fields in the document.
- Keep the game/exporter clock synchronized. A measurement timestamp must not exceed response receipt time. Old but previously unaccepted measurements can be accepted; there is no age cutoff.
- HTTP and HTTPS are both accepted. Redirects are not followed. Poll requests bypass proxy environment variables (`http_proxy`, `HTTP_PROXY`, `https_proxy`, `HTTPS_PROXY`) and connect directly.
