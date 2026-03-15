# Skein Design Plan

This plan is based on the current `%skein` code (`state-24`).

After reviewing the latest transport changes, I do not see a remaining architectural blocker in the `%skein` desk itself. The main mixnet machinery that was previously missing is now present in code:

- signed relay descriptors
- relay provenance metadata and trust labels
- profile-aware cell sizing and timing
- route-set retries with fresh cell rebuild
- fresh route reselection after alternate routes are exhausted
- queued recovery when an initial send has no route
- `intro-v1` bundles with sender-side bundle progress and exhaustion tracking
- receiver-side consumed-entry enforcement
- focused unit tests for bundle progression, no-route queuing, reselection, and duplicate suppression

## Remaining issues

- no new significant architectural vulnerability was identified in the current `%skein` review
- the remaining gap is proof, not missing mechanism: the recent resilience work is covered mostly by unit-style tests, not multi-ship integration or churn testing
- the project still needs evidence that a fresh node can join from a single seed, discover enough relay diversity, and keep delivering traffic while relays disappear and reappear

## Workstream 1: prove single-peer bootstrap and churn recovery end to end

### Goal

Demonstrate that `%skein` actually satisfies the intended join-and-recover behavior in a realistic multi-ship test environment.

### Plan

1. Add an integration harness with multiple ships acting as seeds, relays, and ordinary clients.
2. Start a fresh client with only one known seed and verify that it discovers additional relays and begins delivering contact-routed traffic.
3. Kill entry and middle relays during active sends and verify that queued no-route recovery and reselection complete delivery without manual repair.
4. Assert that duplicate suppression and consumed-entry handling still hold under retries and relay churn.

## Workstream 2: soak-test bundle rotation and recovery behavior

### Goal

Verify that the long-lived transport lifecycle behaves correctly once the desk has been running for hours or days rather than a single request cycle.

### Plan

1. Run a long-duration test that exercises bundle rotation, resend timers, reselection, and cover traffic together.
2. Verify that exhausted intro bundles recover once fresh reply material arrives.
3. Verify that `queued-no-route`, `reselected`, and `exhausted-reselects` counters line up with observed behavior.
4. Prune or tighten any lifecycle state that grows unexpectedly under soak.

## Exit criteria

- a fresh node can join knowing one seed and successfully route application traffic
- relay loss during active traffic does not cause silent permanent failure while reselection budget remains
- intro bundles advance, exhaust, refresh, and recover correctly under repeated use
- soak runs do not reveal unbounded state growth or retry loops
