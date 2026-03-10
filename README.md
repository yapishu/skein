# %skein

A mix-network message router for Urbit. Ships send encrypted messages through chains of relay nodes so that no single hop knows both the sender and recipient. Think Tor-style onion routing, but over Ames, with epoch batching and cover traffic to resist traffic analysis.

## How It Works

Messages are wrapped in relay cells — encrypted envelopes that travel through a sequence of intermediate ships before reaching their destination. Each cell carries a layered header (one encryption layer per hop) and an encrypted payload. When a relay receives a cell, it decrypts its header layer to learn the next hop, strips its layer, and forwards the cell onward. Only the final recipient can decrypt the payload.

### Sending

An app bound to %skein pokes with a `%skein-send` request containing a destination endpoint, payload, and optional route preference. If no route is specified, skein auto-selects one: it picks at least two intermediate relays from the configured relay set, shuffles them by entropy, and builds a multi-hop path to the target. The sender then constructs nested header layers — one per hop, innermost first — each encrypted with a key derived from the relay's public key and the cell's deterministic ID. The payload is sealed with a body-key derived from the final hop's key. The assembled cell is dispatched to the first relay.

### Relaying

When an intermediate node receives a `%skein-cell` poke, it checks expiry, runs replay detection against a seen cache (keyed on cell-id + remaining route, pruned hourly), then tries to decrypt the header with each of its relay keys. On success it peels one layer, reveals the next hop and inner header, and either forwards immediately or queues the cell for the next epoch batch. Forwarding delays and batching — cells are flushed every 30 seconds — prevent timing correlation between incoming and outgoing messages.

### Cover Traffic

Each epoch tick has a 1-in-3 chance of generating a dummy cell routed through a random relay. This adds noise so that an observer can't distinguish real traffic from padding, even during quiet periods.

### Delivery

When a cell arrives at its final destination, skein decrypts the payload with the body-key from the innermost header layer and enqueues the resulting envelope for the bound application. Apps subscribe to `/app/{app-id}/inbox` to receive messages, with backlog delivered on subscription.

## Encryption

The crypto layer uses Urbit's `crub` (Curve25519 + AES) primitives. Key derivation tags (`'skein-hop'` for headers, `'skein-body'` for payloads) ensure header and body keys are distinct even when derived from the same relay key. A null key (`0x0`) means no encryption for that layer, supporting mixed encrypted/unencrypted relay chains.

Header layers nest like Russian dolls: the outermost layer is for the first relay, and each contains the encrypted inner layer for the next hop plus the remaining route. Peeling a layer reveals only the next hop — intermediate relays never see the full path or the payload.

## Configuration

Relay descriptors define available nodes: ship, public key, weight, default delay, and optional expiry. Routes can be manually specified per-message or auto-selected from the relay pool. Admin actions (`%skein-admin`) manage relay descriptors and app bindings.

The agent exposes scry endpoints for state inspection: `/x/stats` for summary metrics, `/x/descriptors` for the relay set, `/x/routes` for recent route selections, and `/x/app/{id}` for per-app binding and queue status.

## State

Agent state (`state-3`) tracks: bound applications, per-app message queues, relay descriptors, a replay-detection seen cache, recent route logs, and mix-state (the current epoch batch and timer). Migration support covers states 0 through 3.
