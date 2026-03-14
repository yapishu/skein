# Skein Design Plan

This plan is based on the `%skein` code that exists now. The goal is not to replace the current transport with a different system. The goal is to harden the current design by extending the pieces that are already live:

- signed relay descriptors
- route health and trust scoring
- opaque contact bundles and reply blocks
- per-hop body peeling and per-hop `cell-id` reassignment
- retry, batching, and lightweight cover traffic

## Design direction

The current `%skein` is already a usable routed transport. The next version should keep the same mental model and improve three things:

1. joining the network from one known peer without giving that peer total control over the visible relay set
2. reducing linkability from repeated contact use, timing, and size
3. making route failure cause delay and reroute, not application-visible collapse

## Workstream 1: turn descriptor provenance into routing policy

Current code already tracks descriptor sources and verifies descriptor signatures. The next change should make provenance affect route eligibility instead of being passive metadata.

### Design change

Add local relay metadata beside each descriptor:

- `sources=(set ship)`
- `first-seen=@da`
- `last-seen=@da`
- `status=?(%provisional %usable %trusted)`
- `family=(unit @t)`

Use the current `descriptor-sources.state`, `trusted.state`, and `health.state` as the base for this local relay view.

### Routing rule

- a relay learned from only one source starts as `%provisional`
- `%provisional` relays may be used for discovery expansion and first-hop fallback, but not as preferred middle hops
- a relay becomes `%usable` after cross-witnessing from multiple sources or explicit operator trust
- `%trusted` remains the manual override that already exists

### Why this fits the current design

- descriptor signature verification already prevents trivial forgery
- source tracking already exists
- route selection already has health and trust weighting

This work mostly changes route admission rules, not the cell format.

### Migration steps

1. Change `descriptor-sources` from a single source to a source set.
2. Build a `relay-meta` map from the current discovery flow.
3. Filter route candidates by local status before score sorting.
4. Surface status and source count on `/x/descriptors` and the HTTP stats view.

## Workstream 2: evolve contact bundles into introduction bundles

Current contact bundles already hide the destination ship from the caller. The next problem is reuse and linkability.

### Design change

Keep the current `contact-v2` idea, but make a minted contact represent a small batch of single-use ingress tokens rather than one long-lived reusable ingress path.

A next-step contact bundle should carry:

- target app
- bundle id
- a small batch of ingress entries
- per-entry expiry
- optional reply policy hints

Each ingress entry should be consumable once. A delivered message should carry fresh reply material so the conversation continues on newly issued ingress entries instead of the original introduction bundle.

### Why this fits the current design

- `%skein` already knows how to mint contacts
- reply blocks are already live
- `%silk` already rotates and republishes contact material

This is an extension of the current contact and reply-block machinery, not a new addressing system.

### Migration steps

1. Keep current `contact-v2` support as a compatibility path.
2. Add local bookkeeping for consumed ingress tokens.
3. Mint contacts as short batches instead of single reusable paths.
4. Reissue fresh reply material automatically on delivery helpers.

## Workstream 3: add fixed transport profiles on top of the existing cell format

The current transport already does onion wrapping and hop-local forwarding. The missing piece is disciplined size shaping.

### Design change

Add a small set of `cell-profile`s, for example:

- `%small`
- `%medium`
- `%large`

Each profile defines:

- padded body size
- padded header size
- delay window defaults
- cover eligibility

Use the existing padding helper and current relay-cell construction, but pad before sealing and standardize the output to the chosen profile.

### Why this fits the current design

- the current `relay-cell` format can absorb a profile field without changing the routing model
- padding support already exists in code
- mix epochs and delays already exist

### Migration steps

1. Add `profile` to `relay-cell` and send options.
2. Pad header and body to the selected profile before encryption.
3. Choose a profile automatically from payload size unless the caller overrides it.
4. Update cover traffic to use the same profiles as real traffic.

## Workstream 4: make resilience route-set based instead of single-route based

Current `%skein` chooses a route per send and retries first-hop failure. That is enough for MVP transport, but not enough for the reliability target.

### Design change

Keep the current route selector, but have it return a small route set:

- one primary route
- one or two alternates with different entry relays and, when possible, different relay families

Send uses the primary route first. Retry promotes an alternate route instead of recomputing from scratch every time.

### Why this fits the current design

- route selection is already local
- health and trust already influence route choice
- retry queues already exist

This change mostly affects send bookkeeping and retry behavior.

### Migration steps

1. Extend recent-route tracking from one route to a route-set view.
2. Store alternate first hops for pending sends.
3. Promote alternates on retry before falling back to a fresh selection.
4. Persist healthy relay observations across restart so a reboot does not reset route quality to zero.

## Workstream 5: keep channels public and add a private introduction path for apps that need it

Channels are useful coordination primitives. They are also public directories.

### Design change

Do not try to make channels private. Keep them as explicit membership surfaces.

For privacy-sensitive apps, add a separate introduction flow built on the contact-bundle work above:

- an app publishes introduction material
- peers exchange opaque contacts through explicit introductions
- no privacy-sensitive app relies on channel membership as a participant directory

### Why this fits the current design

- channel support already works and should stay simple
- `%silk` has already started moving away from channel-based discovery

## Workstream 6: add real integration coverage

The current test desk covers helper behavior. The next phase needs protocol tests.

### Test additions

- descriptor merge tests with mixed good and bad signatures
- route admission tests for `%provisional` versus `%usable` relays
- contact-bundle consumption and reply reissue tests
- multi-hop forwarding tests with per-hop `cell-id` changes
- fixed-profile padding tests
- relay failure and retry-to-alternate-route tests

## Suggested execution order

1. Provenance-aware relay admission
2. Introduction bundles built from the current contact system
3. Fixed-size transport profiles
4. Route-set retries and persisted relay quality
5. Private introductions for apps that need them, while keeping channels explicitly public
6. Integration tests for all of the above
