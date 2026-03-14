# %skein

`%skein` is a routed transport desk for Urbit apps. A local app binds to `%skein`, hands it an opaque payload, and `%skein` delivers that payload over a multi-hop relay path instead of a direct ship-to-ship poke.

It is the transport layer under `%silk`, but it is meant to be reusable by any app that wants routed delivery, relay discovery, reply paths, and basic operator tooling without building a transport stack from scratch.

## What `%skein` does

- Binds local apps so they can send and receive through `%skein`
- Maintains a relay set from discovered relay descriptors
- Selects multi-hop routes with health, trust, and minimum-hop policy
- Mints opaque contact bundles that higher-level apps can hand around
- Builds reply paths so a recipient can answer without a direct `[ship app]` route
- Encrypts a header layer per hop and wraps the body in per-hop layers
- Reassigns the visible `cell-id` at each forward step
- Retries failed first-hop sends with bounded backoff
- Batches delayed forwards and emits simple cover traffic
- Exposes relay events, app inboxes, scries, and a small HTTP operator surface

## What `%skein` is for

Use `%skein` when:

- your app wants to talk to another app over an overlay path instead of a direct poke
- your app wants to publish an opaque contact instead of a raw ship address
- you want replyable asynchronous messaging between Urbit apps

Do not use `%skein` as your only security story if you need:

- protection from a global network observer
- strong Sybil resistance in relay discovery
- private channel membership
- anonymous on-chain payments

## How it works

1. A local app binds to `%skein`.
2. `%skein` discovers relays and keeps their descriptors.
3. The app either targets a direct `[%endpoint [ship app]]` destination or an opaque `[%contact bundle]`.
4. `%skein` chooses a route, encrypts one header layer per hop, and wraps the body in one layer per hop.
5. Each relay opens only its layer, peels one body layer, and forwards the cell.
6. The final `%skein` instance opens the payload and pokes the bound local app.

For contact-bundle sends, the calling app does not need the destination ship. `%skein` resolves the bundle locally.

## Quick start

Bind an app and discover a relay:

```hoon
/-  *skein
:~  [%pass /bind %agent [our %skein] %poke %skein-admin !>([%bind %echo])]
    [%pass /discover %agent [our %skein] %poke %skein-admin !>([%discover-relay ~sampel-palnet])]
==
```

Mint a contact bundle for that app. The `label` lets one app mint more than one distinct contact:

```hoon
/-  *skein
[%pass /contact %agent [our %skein] %poke %skein-admin !>([%mint-contact %echo 0v1])]
.^(noun %gx /=skein=/x/contact/0v1/noun)
```

Send directly to an endpoint:

```hoon
/-  *skein
=/  req=send-request
  [ from=%echo
    to=[%endpoint [~sampel-palnet %echo]]
    payload=[%say 'hello over skein']
    opts=[route=~ reply-blocks=~ ttl=~]
  ]
[%pass /send %agent [our %skein] %poke %skein-send !>(req)]
```

Watch relay events and the bound app inbox:

```hoon
[%pass /relay-events %agent [our %skein] %watch /relay/events]
[%pass /echo-inbox %agent [our %skein] %watch /app/echo/inbox]
```

Inspect state:

```hoon
.^(noun %gx /=skein=/x/stats/noun)
.^(noun %gx /=skein=/x/descriptors/noun)
.^(noun %gx /=skein=/x/routes/noun)
```

## Privacy model

What `%skein` currently provides:

- relays only learn their local hop instruction, not the whole path
- the body is wrapped per hop, so non-final relays are not supposed to see the delivered payload
- contact bundles do not expose a raw destination endpoint to the calling app
- reply paths are live, so higher-level apps can answer without storing a direct route

What `%skein` still leaks or does not solve:

- relay discovery is still bootstrap-driven and not Sybil-hard
- traffic timing, coarse size, and first-hop behavior still leak metadata
- channels are explicit membership directories if you use them
- cover traffic is lightweight, not a high-assurance anonymity defense
- on-chain settlement is outside `%skein`

The right way to describe `%skein` today is: a useful routed transport with meaningful privacy improvements over direct app-to-app pokes, not a complete anonymity system.

## Operator surface

Marks:

- `%skein-admin`
- `%skein-send`
- `%skein-cell`
- `%skein-event`
- `%skein-relay-pool`
- `%skein-channel`

Common admin actions:

- `%bind` / `%unbind`
- `%discover-relay`
- `%mint-contact`
- `%build-reply-block`
- `%set-min-hops`
- `%set-adaptive-hops`
- `%trust-relay` / `%untrust-relay`
- `%add-seed` / `%drop-seed`
- `%join-channel` / `%leave-channel`

Watches:

- `/relay/events`
- `/relay/pool`
- `/channel/<channel-id>`
- `/app/<app>/inbox`

Scries:

- `/x/state`
- `/x/descriptors`
- `/x/routes`
- `/x/stats`
- `/x/contact/<label>`
- `/x/reply-block`

## Relationship to `%silk`

`%skein` is transport only. `%silk` adds marketplace identities, listings, negotiation, escrow, moderators, and reputation on top of it.
