# %skein

`%skein` is a Gall mixnet transport for Urbit. It moves opaque app payloads through relay chains so that each hop only learns its immediate forwarding step. The desk is application-agnostic; `../silk` uses it as its transport layer.

## Current Status

Implemented today:

- app bind/unbind and per-app inbox queues
- relay descriptor gossip via `/relay/pool`
- channel-based peer discovery with lightweight membership directories
- source-selected multi-hop routes with layered encrypted headers
- encrypted payload bodies
- replay detection keyed by `cell-id`
- delayed forwarding with epoch batching
- adaptive cover traffic (paces itself based on real send activity)
- weighted route selection using descriptor weight, relay health tracking, and operator trust sets
- multiple configurable bootstrap seeds (default: `~sovsef-risfex-sitful-hatred`)
- adaptive minimum hops (automatically raises the floor as more relays appear)
- relay health tracking with success/failure counts and last-fail timestamps
- operator-curated relay trust lists with weighted preference
- descriptor source tracking (who told us about each relay)
- bounded retry with backoff for failed cell delivery
- reply-token storage for reply blocks
- JSON control API and a Vite-based operator UI
- state migrations through `state-17`

Still missing or intentionally simple:

- reply blocks are typed and tokens are stored, but reply-block construction and use is not yet exercised
- cells are not fixed-size or padded
- forwarding peels a layer but does not do Sphinx-style re-encapsulation
- descriptor trust is local and operator-managed; there is no signed multi-source directory

The current implementation is a useful private transport substrate with real route diversity, health awareness, and cover traffic, but it should not yet be described as a finished anonymity system.

## Transport Model

Core types live in `desk/sur/skein.hoon`.

- `endpoint`: `[ship app]`
- `relay-descriptor`: relay id, ship, relay key, weight, default delay, optional expiry
- `route`: ordered list of `route-hop`s plus a `route-id`
- `relay-cell`: `cell-id`, encrypted header, encrypted body, optional expiry
- `send-request`: local app, destination endpoint, opaque payload, optional route/ttl
- `channel-update`: `%join`, `%leave`, or `%members` for discovery channels

Route selection is local and weighted. If a caller does not supply a route, `%skein` selects intermediate relays from the known pool using a scoring function that considers descriptor weight, relay health (success/failure ratio), and operator trust. Trusted relays receive a configurable weight boost. The effective `min-hops` is either the manual setting or an adaptive floor based on relay pool size (3+ relays = 1 hop, 6+ relays = 2 hops), whichever is higher when adaptive mode is on.

## What The Agent Does

The only live agent is `desk/app/skein.hoon`.

On send:

- validates that the source app is bound
- short-circuits same-ship delivery when no remote route is needed
- auto-selects or hydrates a route using weighted scoring
- builds a layered encrypted header and encrypted body
- dispatches immediately or queues for the next epoch if a hop has a delay
- records a bounded recent-route log
- tracks the last real send time for adaptive cover pacing

On relay:

- drops expired cells
- drops replayed `cell-id`s from the seen cache
- decrypts exactly one local header layer
- either forwards to the next hop or decrypts and delivers the payload at the destination
- updates relay health counters (success on forward/deliver, failure on error)
- queues failed cells for bounded retry with backoff

On delivery:

- stores the envelope in the target app queue
- emits `/relay/events`
- emits `/app/<app>/inbox`
- pokes the bound local app with the opaque payload

## Discovery And Channels

Relay discovery is pool-gossip based with configurable seeds.

- each node publishes its own descriptor plus its known relay pool on `/relay/pool`
- new pool entries are merged locally, capped by `max-relays`
- the desk bootstraps by subscribing to a configurable set of seed ships (default: `~sovsef-risfex-sitful-hatred`)
- operators can add or remove seeds at runtime; new relays discovered through any seed are auto-subscribed for channels

Channels provide a lightweight shared membership directory on top of the relay network.

- apps can join a named `channel-id`
- `%skein` subscribes to that channel across all known relays
- channel membership updates (`%join`, `%leave`, `%members`) are forwarded to the joined app as tagged `%noun` pokes
- `../silk` uses the `%silk-market` channel to discover marketplace peers automatically

## Interfaces

### Gall Marks

- `%skein-admin`
- `%skein-send`
- `%skein-cell`
- `%skein-event`
- `%skein-relay-pool`
- `%skein-channel`

### Admin Actions

- `%bind` / `%unbind`: register or deregister an app
- `%clear`: flush an app's inbox queue
- `%put-relay` / `%drop-relay` / `%discover-relay`: manage the relay pool
- `%clear-seen`: flush the replay cache
- `%join-channel` / `%leave-channel`: subscribe to discovery channels
- `%set-min-hops`: set the manual minimum relay hop count
- `%add-seed` / `%drop-seed`: manage bootstrap seed ships
- `%set-adaptive-hops`: toggle adaptive minimum hops based on pool size
- `%trust-relay` / `%untrust-relay`: manage the operator trust set

### Watches

- `/relay/events`
- `/relay/pool`
- `/channel/<channel-id>`
- `/app/<app>/inbox`

### Scries

- `/x/state`
- `/x/app/<app>`
- `/x/descriptors`
- `/x/routes`
- `/x/stats`

### HTTP API

Authenticated via Eyre session cookie at `/apps/skein/api`.

`GET` endpoints:

- `/stats` — includes relay count, effective min-hops, adaptive-hops flag, health summary
- `/relays`
- `/routes`
- `/apps`
- `/batch`
- `/channels`
- `/health` — relay health counters
- `/trusted` — operator trust set

`POST` actions:

```json
{"action":"put-relay","ship":"~sampel-palnet"}
{"action":"drop-relay","relay":"~sampel-palnet"}
{"action":"clear-seen"}
{"action":"bind-app","app":"silk-core"}
{"action":"unbind-app","app":"silk-core"}
{"action":"join-channel","channel":"silk-market","app":"silk-core"}
{"action":"leave-channel","channel":"silk-market"}
{"action":"set-min-hops","n":2}
{"action":"add-seed","ship":"~sampel-palnet"}
{"action":"drop-seed","ship":"~sampel-palnet"}
{"action":"set-adaptive-hops","on":true}
{"action":"trust-relay","relay":"~sampel-palnet"}
{"action":"untrust-relay","relay":"~sampel-palnet"}
```

`put-relay` means "discover this ship and subscribe to its relay pool"; it does not directly install an arbitrary descriptor from JSON.

## Operator UI And Sync

The repo ships a standalone Vite single-page dashboard in `ui/`.

- reads `/apps/skein/api/{stats,apps,relays,routes,batch,health,trusted,channels}`
- exposes relay discovery, bind/unbind, seed management, trust management, adaptive hops, and replay-cache management
- is bundled to a single file with `vite-plugin-singlefile`

`./sync` builds the UI, globs the bundle, uploads to R2, updates `desk/desk.docket-0`, and rsyncs the desk to the configured pier path.

## Tests

`desk/tests/app/skein.hoon` currently covers:

- jam/cue round-trips
- deterministic `cell-id` derivation
- tag-separated key derivation
- replay-cache pruning
- `crub` encryption round-trips
- header-layer and nested-header round-trips

The tests are useful sanity checks, but they are still small relative to the transport surface.

## Known Gaps

The important remaining holes are:

- reply-block construction and anonymous return-path support are not yet exercised (token storage exists)
- no fixed-shape cells or payload-size hiding
- no packet normalization or re-randomization on forward, so single-hop tagging resistance is weaker than the architecture target
- no signed relay descriptors; trust is local and operator-managed
- descriptor source tracking exists but there is no multi-source validation or Sybil resistance
- cover traffic is adaptive but simple; no multiple cover classes or traffic-shape matching
