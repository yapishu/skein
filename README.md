# %skein

`%skein` is a Gall mixnet transport for Urbit. It moves opaque app payloads through relay chains so that each hop only learns its immediate forwarding step. The desk is application-agnostic; `../silk` uses it as its transport layer.

## Current Status

Implemented today:

- app bind/unbind and per-app inbox queues
- relay descriptor gossip via `/relay/pool`
- channel-based peer discovery
- source-selected multi-hop routes with layered encrypted headers
- encrypted payload bodies
- replay detection keyed by `cell-id`
- delayed forwarding with epoch batching
- opportunistic cover traffic
- JSON control API and a Vite-based operator UI
- state migrations through `state-14`

Still missing or intentionally simple:

- reply blocks are typed but not used
- relay descriptor `weight` is stored but not used in route selection
- cells are not fixed-size or padded
- forwarding peels a layer but does not do Sphinx-style re-encapsulation
- descriptor trust is local and optimistic; there is no signed multi-source directory

The current implementation is a useful private transport substrate, but it should not yet be described as a finished anonymity system.

## Transport Model

Core types live in `desk/sur/skein.hoon`.

- `endpoint`: `[ship app]`
- `relay-descriptor`: relay id, ship, relay key, weight, default delay, optional expiry
- `route`: ordered list of `route-hop`s plus a `route-id`
- `relay-cell`: `cell-id`, encrypted header, encrypted body, optional expiry
- `send-request`: local app, destination endpoint, opaque payload, optional route/ttl
- `channel-update`: `%join`, `%leave`, or `%members` for discovery channels

Route selection is local. If a caller does not supply a route, `%skein` chooses a set of distinct intermediate relays from the known pool, excludes self and the target, then appends the target ship as the final hop when that ship has a descriptor. `min-hops` controls the number of intermediate relays to require.

## What The Agent Does

The only live agent is `desk/app/skein.hoon`.

On send:

- validates that the source app is bound
- short-circuits same-ship delivery when no remote route is needed
- auto-selects or hydrates a route
- builds a layered encrypted header and encrypted body
- dispatches immediately or queues for the next epoch if a hop has a delay
- records a bounded recent-route log

On relay:

- drops expired cells
- drops replayed `cell-id`s from the seen cache
- decrypts exactly one local header layer
- either forwards to the next hop or decrypts and delivers the payload at the destination

On delivery:

- stores the envelope in the target app queue
- emits `/relay/events`
- emits `/app/<app>/inbox`
- pokes the bound local app with the opaque payload

## Discovery And Channels

Relay discovery is currently pool-gossip based.

- each node publishes its own descriptor plus its known relay pool on `/relay/pool`
- new pool entries are merged locally, capped by `max-relays`
- the desk bootstraps by subscribing to a hard-coded ship: `~sovsef-risfex-sitful-hatred`

Channels provide a lightweight shared membership directory on top of the relay network.

- apps can join a named `channel-id`
- `%skein` subscribes to that channel across known relays
- channel membership updates are forwarded to the joined app as tagged `%noun` pokes
- `../silk` uses this to discover marketplace peers

## Interfaces

### Gall Marks

- `%skein-admin`
- `%skein-send`
- `%skein-cell`
- `%skein-event`
- `%skein-relay-pool`
- `%skein-channel`

### Admin Actions

- `%bind`
- `%unbind`
- `%clear`
- `%put-relay`
- `%drop-relay`
- `%discover-relay`
- `%clear-seen`
- `%join-channel`
- `%leave-channel`
- `%set-min-hops`

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

- `/stats`
- `/relays`
- `/routes`
- `/apps`
- `/batch`
- `/channels`

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
```

`put-relay` currently means "discover this ship and subscribe to its relay pool"; it does not directly install an arbitrary descriptor from JSON.

## Operator UI And Sync

The repo ships a standalone Vite single-page dashboard in `ui/`.

- reads `/apps/skein/api/{stats,apps,relays,routes,batch}`
- exposes relay discovery, bind/unbind, and replay-cache management
- is bundled to a single file with `vite-plugin-singlefile`

`./sync` builds the UI, globs the bundle, updates `desk/desk.docket-0`, and rsyncs the desk to the configured pier path.

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

- no reply-block construction or anonymous return-path support
- no fixed-shape cells or payload-size hiding
- no packet normalization or re-randomization on forward, so single-hop tagging resistance is weaker than the architecture target
- no descriptor signatures, relay reputation, or Sybil resistance
- no weighted route selection despite the `weight` field
- `default-min-hops` is `0`, so privacy depends on operator configuration and relay availability

That makes `%skein` a good experimental transport desk and a workable substrate for `%silk`, but not yet the final "transparent mixnet" described in the long-term design notes.
