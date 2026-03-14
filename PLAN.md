# Skein Plan

This plan is based on the current `%skein` code, not the older aspirational security story.

## North Star

- Useful routed transport for higher-level apps like `%silk`
- Real confidentiality of payloads and remaining route against curious relays
- Better unlinkability across hops
- Better discovery trust and lower eclipse / Sybil risk
- Clear documentation of what `%skein` does and does not protect

## Priority 0: Stop Publishing Relay Decryption Keys

- Remove symmetric relay decryption keys from relay descriptors
- Replace them with public descriptor material suitable for per-hop header sealing
- Make sure a relay can open only its own layer, not every downstream layer
- Revisit final-hop body-key delivery so a curious intermediate relay cannot recover it from the remaining header
- Add a real authenticity story so routed envelopes cannot simply claim an arbitrary `origin`

Done when:

- a relay pool subscriber cannot decrypt arbitrary cells just from the descriptor set
- a single curious relay on a path no longer defeats remaining-route secrecy by design

## Priority 1: Remove Cross-Hop Linkability

- Stop forwarding stable cells with the same clear `cell-id`
- Re-randomize or re-encapsulate on every hop instead of just peeling a header
- Avoid forwarding the encrypted body byte-for-byte unchanged
- Revisit replay detection so it still works without a globally stable visible id

Done when:

- downstream observers cannot trivially correlate the same packet by id or unchanged ciphertext
- tagging resistance is stronger than the current baseline

## Priority 2: Strengthen Discovery And Seed Posture

- Add signed relay descriptors
- Validate descriptors from more than one source
- Reduce dependence on a single default seed
- Make eclipse and Sybil attacks harder than "be the first pool source"
- Tighten expiry and freshness handling

Done when:

- discovery is not blind trust in whoever answered `/relay/pool`
- a malicious seed or early peer has less power to define the visible network

## Priority 3: Finish Reply Blocks

- Wire reply blocks into the live send path
- Decide reply-block lifecycle:
  - single-use
  - short-lived
  - failure behavior
- Make replies usable by higher-level apps without exposing sender transport identity directly

Done when:

- recipients can reply without a direct sender route
- reply blocks are more than a stored token and a debug builder

## Priority 4: Improve Size Hiding

- Keep minimum body padding
- Add header padding
- Decide fixed-size cells or a small set of cell profiles
- Test body / header size leakage under normal app traffic

Done when:

- cell size leaks materially less application information
- route length and small payload size are less obvious

## Priority 5: Revisit Channel Privacy

- Decide whether channels are meant to be explicit membership directories
- If yes, document that clearly and keep them out of anonymity claims
- If no, design a different peer-discovery mechanism for privacy-sensitive apps

Done when:

- `%silk` and other apps are not accidentally relying on channels for private discovery
- channel privacy properties are explicit rather than implied

## Priority 6: Keep Reliability And Cover Useful

- Keep retry bounded and predictable
- Improve observability around batch queues and retry queues
- Tune cover traffic beyond a simple chance-based policy
- Make cover paths and timing less mechanically distinct from real traffic

Done when:

- ordinary relay churn causes delay rather than collapse
- cover traffic helps against quiet-period leakage without becoming noisy nonsense

## Testing Plan

- Add tests that model a curious relay with access to the relay pool
- Add forwarding-correlation tests for stable `cell-id` and unchanged body bytes
- Add discovery tests for malicious pool injection and seed bias
- Add reply-block integration tests
- Add channel-membership privacy tests or explicit documentation tests
- Keep the existing crypto round-trip tests, but stop treating them as security coverage

## Suggested Execution Order

1. Stop publishing relay decryption keys
2. Remove cross-hop linkability and add re-encapsulation
3. Strengthen discovery trust and seed posture
4. Wire reply blocks into the live transport path
5. Add header padding and better size hiding
6. Revisit channel privacy semantics
7. Tune reliability and cover traffic
