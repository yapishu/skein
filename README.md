# %skein

`%skein` is an experimental Gall routed transport for Urbit. It moves opaque app payloads through relay chains and is application-agnostic; `../silk` uses it as its transport layer.

The current implementation is useful as a routed delivery substrate with batching, retries, health-aware route selection, and cover traffic. It is not yet a safe anonymity system, and it should not currently be described as a finished mixnet.

## Current Status

Implemented today:

- app bind / unbind and per-app inbox queues
- relay descriptor gossip via `/relay/pool`
- source-selected multi-hop routes with layered encrypted headers
- encrypted payload bodies
- minimum body padding to 8KB before body encryption
- replay detection keyed by clear `cell-id`
- delayed forwarding with epoch batching
- weighted route selection using descriptor weight, relay health tracking, and operator trust sets
- simple recent-route avoidance for repeated sends to the same target
- multiple configurable bootstrap seeds, with one default seed baked in
- adaptive minimum hops based on relay pool size
- relay health tracking with success / failure counts and last-fail timestamps
- operator-curated relay trust lists with weighted preference
- descriptor source tracking
- bounded retry with backoff for failed first-hop delivery
- adaptive cover traffic tied to recent real send activity
- reply-block construction and reply-token storage
- channel-based peer discovery with `%join`, `%leave`, and `%members`
- JSON control API and a Vite-based operator UI
- state migrations through `state-17`

Not yet secure enough to over-claim:

- relay descriptors currently publish the relay symmetric key, so any node with the relay pool can peel remaining header layers on any cell it sees
- the final header layer carries the body key, so a node that can open the remaining header can also decrypt the body
- cells do not cryptographically authenticate the claimed `origin`, so a participant with the relay pool can fabricate cells that impersonate arbitrary routed senders
- `cell-id` is clear and stable across hops, and forwarding preserves the encrypted body unchanged
- there is no Sphinx-style re-encapsulation, packet normalization, or hop-local rerandomization
- there is no signed multi-source directory; discovery is still unsigned pool gossip
- reply blocks are buildable but not yet part of the live send / receive path
- headers are not padded even though a `min-header-size` constant exists
- cells are not fixed-size; only the body gets minimum padding
- channel membership is visible to channel subscribers

## Security Reality Today

The code does have a blind cell format in the narrow sense that a `relay-cell` does not carry cleartext origin, target, or route fields.

That is not enough to give relay privacy in the stronger sense, because the current implementation also does the following:

- publishes each relay's symmetric hop key inside the relay descriptor
- uses those descriptor keys directly to derive per-hop header decryption keys
- places the body decryption key in the final header layer
- forwards the body and `cell-id` unchanged across hops

The result is:

- an honest relay can mechanically forward based only on its local layer
- a curious relay that has the relay pool can peel all remaining layers on any cell it sees
- a curious first hop learns the sender ship from Gall transport and can also recover the rest of the route and the payload
- a curious middle hop learns its predecessor from Gall transport and can recover the rest of the route and the payload
- a participant with relay-pool access can mint spoofed cells that claim arbitrary `origin` endpoints
- channel subscribers can enumerate channel members directly

So the current security story is closer to "opaque routed transport among cooperative relays" than "cryptographically blind mixnet against curious relays."

## Transport Model

Core types live in `desk/sur/skein.hoon`.

- `endpoint`: `[ship app]`
- `relay-descriptor`: relay id, ship, symmetric relay key, weight, default delay, optional expiry
- `route`: ordered list of `route-hop`s plus a `route-id`
- `relay-cell`: clear `cell-id`, encrypted header, encrypted body, optional expiry
- `send-request`: local app, destination endpoint, opaque payload, optional route / ttl / reply blocks
- `channel-update`: `%join`, `%leave`, or `%members` for discovery channels

Route selection is local and weighted. If a caller does not supply a route, `%skein` selects intermediate relays from the known pool using descriptor weight, relay health, and operator trust. Trusted relays receive a weight boost. The effective `min-hops` is either the manual setting or an adaptive floor based on relay pool size.

## What The Agent Does

The only live agent is `desk/app/skein.hoon`.

On send:

- validates that the source app is bound
- short-circuits same-ship delivery when no remote route is needed
- auto-selects or hydrates a route
- builds a layered encrypted header from relay descriptor keys
- encrypts the body and pads it to at least 8KB first
- dispatches immediately or queues for the next epoch if a hop has a delay
- records a bounded recent-route log
- tracks the last real send time for adaptive cover pacing

On relay:

- drops expired cells
- drops replayed `cell-id`s from the seen cache
- decrypts one local header layer
- either forwards to the next hop or decrypts and delivers the body at the destination
- updates relay health counters from poke acks
- queues failed first-hop sends for bounded retry with backoff

On delivery:

- stores the envelope in the target app queue
- emits `/relay/events`
- emits `/app/<app>/inbox`
- pokes the bound local app with the opaque payload

## Discovery And Channels

Relay discovery is unsigned pool-gossip based with configurable seeds.

- each node publishes its own descriptor plus its known relay pool on `/relay/pool`
- new pool entries are merged locally, capped by `max-relays`
- the desk bootstraps by subscribing to a configurable seed set
- the current default still hardcodes one seed ship: `~sovsef-risfex-sitful-hatred`
- new relays discovered through any watched pool are auto-subscribed

Channels provide a lightweight shared membership directory on top of the relay network.

- apps can join a named `channel-id`
- `%skein` subscribes to that channel across all known relays
- channel membership updates (`%join`, `%leave`, `%members`) are forwarded to the joined app as tagged `%noun` pokes
- subscribers receive full membership lists and join / leave events
- `../silk` uses the `%silk-market` channel to discover marketplace peers automatically

Channels are useful for discovery, not for membership privacy.

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
- `%build-reply-block`: build and store a reply block token
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
- `/x/reply-block`
- `/x/health`
- `/x/trusted`
- `/x/seeds`

### HTTP API

Authenticated via Eyre session cookie at `/apps/skein/api`.

`GET` endpoints:

- `/stats`
- `/relays`
- `/routes`
- `/apps`
- `/batch`
- `/channels`
- `/health`
- `/trusted`

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
{"action":"build-reply-block"}
{"action":"trust-relay","relay":"~sampel-palnet"}
{"action":"untrust-relay","relay":"~sampel-palnet"}
```

`put-relay` means "discover this ship and subscribe to its relay pool"; it does not directly install an arbitrary descriptor from JSON.

## Operator UI And Sync

The repo ships a standalone Vite single-page dashboard in `ui/`.

- reads `/apps/skein/api/{stats,apps,relays,routes,batch,health,trusted,channels}`
- exposes relay discovery, bind / unbind, seed management, trust management, adaptive hops, and replay-cache management
- is bundled to a single file with `vite-plugin-singlefile`

`./sync` builds the UI, globs the bundle, uploads to R2, updates `desk/desk.docket-0`, and rsyncs the desk to the configured pier path.

## Tests

`desk/tests/app/skein.hoon` currently covers:

- jam / cue round-trips
- deterministic `cell-id` derivation
- tag-separated key derivation
- replay-cache pruning
- `crub` encryption round-trips
- header-layer and nested-header round-trips

The tests are still sanity checks, not transport-security proofs.

## Known Gaps

The important remaining holes are:

- stop publishing relay decryption keys in relay descriptors
- move to public-key descriptor material and actual per-hop secrecy
- add a real authenticity story for routed envelopes instead of trusting the claimed `origin` inside the decrypted body
- remove stable cross-hop linkability from clear `cell-id` and unchanged forwarded body bytes
- add hop-local rerandomization / re-encapsulation instead of simple header peeling
- wire reply blocks into the live send / receive path
- sign relay descriptors and validate them across multiple sources
- reduce seed centralization and improve discovery eclipse resistance
- add header padding and fixed-size or profiled cells
- decide whether channels should remain explicit membership directories or be replaced for privacy-sensitive discovery
