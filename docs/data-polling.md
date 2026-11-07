# Data Polling

TreeStats normally stores data sent to it by the [Decal plugin](https://github.com/amoeba/treestats).
This limits the data we have because not everyone run's the plugin.
Additionally, for data like server population counts, even plugin user may not give very fine-grained data because the plugin only sends population data when the player logs into the game world and players don't always relog often.

This documents how TreeStats can poll external HTTP endpoints for data in order to augment plugin-collected data.
At this time, we only support polling for population count data but this could be extended in the future to handle other data.

## Polling Targets

Targets are defined in `./config/polling_targets.yml`:

```yaml
interval: 15m
targets:
  Example Server: https://status.example.net/population.json
```

The `interval` field is global for all targets and defines how often we poll all of them.
`interval` accepts friendly units such as `15m`, `30 mins`, `1hr`, `6 hours`, or `1d`. Minute intervals must divide an hour evenly (1, 2, 3, 4, 5, 6, 10, 12, 15, 20, or 30), and hour intervals must divide a day evenly (1, 2, 3, 4, 6, 8, 12, or 24). The process fails fast at boot on an unsupported value, and changing it requires restarting the Sidekiq worker so the cron schedule is reloaded.

## Target Response

The target must respond with a JSON document with this structure:

```json
{"count": 42, "updated_at": 1760000000}
```

- `count` is a nonnegative integer counting connected, in-world player characters, including bots, multiboxed characters, staff, and test characters. Do not count unique people/accounts or exclude operator-defined categories. A measured empty world is `0`; inability to measure must be an error, not a fabricated zero.
- `updated_at` is the integer Unix timestamp in UTC seconds when the population was measured/refreshed, not when the document was served. Advance it for a new measurement even if the count did not change. Re-serving an old snapshot must not renew it.
- Other JSON fields are ignored. TreeStats binds the server identity from reviewed configuration; do not rely on identity or provenance fields in the document.
- Keep the game/exporter clock synchronized. A measurement timestamp must not exceed response receipt time. Old but previously unaccepted measurements can be accepted; there is no age cutoff.
