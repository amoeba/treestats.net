# Data Polling

TreeStats normally stores data sent to it by the [Decal plugin](https://github.com/amoeba/treestats).
This limits the data we have because not everyone run's the plugin.
Additionally, for data like server population counts, even plugin user may not give very fine-grained data because the plugin only sends population data when the player logs into the game world and players don't always relog often.

This documents how TreeStats can poll external HTTP endpoints for data in order to augment plugin-collected data.
At this time, we only support polling for population count data but this could be extended in the future to handle other data.

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
A `url` overrides the root endpoints and is used as-is, with no fallback. The server name must match an entry in `./data/servers.rb` even when `url` is set. Disabled entries can stay in the file without being polled.

The `interval` field is global for all targets and defines how often we poll all of them.
`interval` accepts friendly units such as `15m`, `30 mins`, `1hr`, `6 hours`, or `1d`. Minute intervals must divide an hour evenly (1, 2, 3, 4, 5, 6, 10, 12, 15, 20, or 30), and hour intervals must divide a day evenly (1, 2, 3, 4, 6, 8, 12, or 24). The process fails fast at boot on an unsupported interval or an invalid target configuration. Changing the interval requires restarting the Sidekiq worker so the cron schedule is reloaded.

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

When `population` is present, the top-level `updated_at` is required as well. A document without `population` is valid: TreeStats records no observation and shows the poll as `empty` in the admin dashboard.

- `count` is a nonnegative integer counting connected, in-world player characters, including bots, multiboxed characters, staff, and test characters. Do not count unique people/accounts or exclude operator-defined categories. A measured empty world is `0`; inability to measure must be an error, not a fabricated zero.
- `updated_at` is when the population was measured, not when the document was served, and is an RFC3339 string with an explicit offset. Advance it for a new measurement even if the count did not change. Re-serving an old snapshot must not renew it.
- Other JSON fields, including `schema`, `version`, `name`, and `emulator`, are ignored for now. TreeStats binds the server identity from reviewed configuration; do not rely on identity or provenance fields in the document.
- Keep the game/exporter clock synchronized. A measurement timestamp must not exceed response receipt time. Old but previously unaccepted measurements can be accepted; there is no age cutoff.
- HTTP and HTTPS are both accepted. Redirects are not followed.
