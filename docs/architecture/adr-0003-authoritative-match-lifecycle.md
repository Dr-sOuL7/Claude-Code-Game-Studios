# ADR-0003: Authoritative Match Lifecycle — Commit, Resolve, Timers, Reconnection

## Status

Accepted

> Only the user (or `technical-director` on the user's explicit confirmation) may set `Accepted`.

## Date

2026-11-09 (proposed); accepted 2026-11-14

## Last Verified

2026-11-09 (design reasoning against `combat-system.md` v0.2 and the Godot 4.7 browser limits in ADR-0002; timer and grace values are PROPOSED defaults, GDD decision O5 is open)

## Decision Makers

Owner (accepted 2026-11-14, on Claude's recommendation); authored by Claude.

## Summary

Each online match is an in-memory state machine on the headless server: both players commit an action in secret, the server resolves the turn atomically with the shared combat engine, and results are persisted write-behind from a seed plus action log. Timers are server-owned and a dropped client can resume with a token.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 |
| **Domain** | Networking |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH |
| **References Consulted** | ADR-0002 sources; Godot 4.7 "Exporting for the Web" (background-tab pause) |
| **Post-Cutoff APIs Used** | None (`Timer`/`SceneTreeTimer`, `HTTPRequest`, `Dictionary`) |
| **Verification Required** | Server tick behaviour under many matches (the Godot main loop is single-threaded for game logic — verify no blocking calls in the resolve path); reconnect within the grace window on real phones |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0002 |
| **Enables** | Matchmaking, Spectator, History epics |
| **Blocks** | Online PvP epic |
| **Ordering Note** | Needs ADR-0004 tables before persistence stories; can be built against an in-memory store first |

## Context

### Problem Statement
Online play needs hidden simultaneous commits, fair timing, duplicate/forged-action protection, and recovery from mobile-web disconnects, while remaining a single authority.

### Constraints
- Browser tabs pause when backgrounded (Godot 4.7 web docs), so disconnects are normal, not exceptional.
- The server runs game logic in the Godot main loop (single-threaded), which removes data races between matches but makes any blocking call a stall for everyone.
- Persistence goes through network calls (`HTTPRequest` to Supabase), which are asynchronous.

### Requirements (from the owner's directive)
Turn timers, timeout handling, duplicate-action prevention, match persistence, reconnection, server-side calculation, atomic turn resolution, concurrency protection, spectators that cannot influence combat.

## Decision

### States
```
QUEUED ─► MATCHED ─► BUILDS_LOCKED ─► TURN_OPEN ─► RESOLVING ─► (TURN_OPEN | FINISHED)
                                         ▲  │ per-player sub-state: CONNECTED | DISCONNECTED(grace) | FORFEIT
                                         └──┘ (resume)
```

### Turn protocol
1. `turn_open{turn, deadline_ms}` is sent to both players and spectators.
2. A player's `action{match_id, turn, action}` is validated (right match, right player, right turn, legal for state) and stored as pending. The opponent receives only `opponent_committed`.
3. When both are present, or the deadline passes, the server resolves **synchronously and atomically**: `CombatEngine.resolve_turn(state, a, b)` (ADR-0001). There is no await between reading the two actions and writing the new state.
4. The server broadcasts `turn_resolved{events, public_state}` to players and spectators, then queues persistence.

### Rules
- **Duplicate prevention**: one pending action per `(match, turn, player)`. A repeat of the same action is acknowledged idempotently; a different action for the same turn is rejected (`already_committed`) and never overwrites. Actions for the wrong turn are rejected.
- **Timeout**: at the deadline a missing action becomes the ruleset's `timeout_action` (PROPOSED default `DEFEND`; GDD O5) and the event stream marks it. PROPOSED default timer 30 s, tunable per mode in the ruleset.
- **Disconnect**: the match is **not paused** (pausing invites stalling). A disconnected player's turns time out. PROPOSED: 3 consecutive timeouts ⇒ forfeit; a client that returns inside that window sends `resume{match_id, resume_token}` and gets `state_snapshot` (public state + its own pending-commit flag + events since its last seen turn).
- **Resume token**: random, per player per match, stored server-side, invalidated at match end. The Supabase JWT in `hello` identifies the account; the resume token binds a reconnect to a match.
- **Spectators**: receive only `turn_open` and `turn_resolved`/`match_finished`. They have no `action` permission; the server rejects any spectator frame that is not `ping`/`leave`. Pending commits are never sent.
- **Finish**: engine reports `Burst | Ring-Out | Spin Finish | Draw`; the server writes the result, updates ratings (ADR-0004) and closes the match.
- **Concurrency**: all mutation of one match happens in the server's single main-thread logic; no per-match locks are needed. Any blocking call in the resolve path is forbidden (HTTP is non-blocking and runs after the broadcast).

### Persistence (write-behind, ordered per match)
`matches` row at creation `(id, ruleset_version, seed, build_a, build_b, players, status)`; `match_turns (match_id, turn, action_a, action_b, events)` after each turn; `UNIQUE (match_id, turn)` makes a replayed write harmless. On server restart the server rebuilds `MatchState` from `seed + action log` for every active match and waits for resumes. A turn that was open but not yet persisted is re-opened and both players re-commit (documented, accepted loss of at most one turn of input).

### Matchmaking and invitations
In-memory queue ordered by rating with a window that widens with wait time; a private invite is a short-lived code; a direct challenge goes to a registered online player. No matching criterion may depend on item power (there is none).

### Implementation Guidelines
- The match actor **must** be a plain `RefCounted` class driven by the server loop; **must not** use scene nodes for match state.
- The resolve path **must not** `await` or call `HTTPRequest`.
- Persistence writes **must** be queued per match and retried with backoff; a persistence failure **must not** stop the match.
- Every state change **must** be loggable as a structured event (`production/` log, not player data).
- Timer values, grace and forfeit counts **must** come from the ruleset/config, not constants.

## Alternatives Considered

### Alternative 1: Pause the match on disconnect
- **Pros**: Kind to flaky connections.
- **Cons**: Trivial stall/abuse; opponent waits indefinitely.
- **Rejection Reason**: Fairness; the grace-by-timeouts design bounds the wait.

### Alternative 2: Process per match
- **Pros**: Isolation.
- **Cons**: Heavy for thousands of tiny matches; complicates matchmaking.
- **Rejection Reason**: Not needed at v1 scale; revisit if load tests demand it.

### Alternative 3: Client commits a hash first (commit-reveal)
- **Pros**: Cryptographic hiding without trusting the server.
- **Cons**: The server is already trusted as the authority; extra round trip and complexity.
- **Rejection Reason**: The server never reveals pending actions; commit-reveal adds nothing.

## Consequences

### Positive
- Deterministic, replayable match history from seed + actions.
- No concurrency bugs between matches by construction.

### Negative
- One server process is a single point of failure in v1; restart loses at most the in-flight turn.
- Write-behind persistence means a crash can lose the last unpersisted turn.

### Neutral
- Spectating and replay share the same event format.

## Risks
- Timeout default (`DEFEND`) may be exploitable (GDD O5). *Mitigation*: simulate timeout abuse in the balance harness before launch.
- Many simultaneous matches could stall the main loop. *Mitigation*: load test; shard by match id if needed.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-system.md | Hidden simultaneous commit (Core Rule 4, AC-7) | Pending actions never leave the server before resolution |
| combat-system.md | E9 timer expiry behaviour (open O5) | Timeout action and forfeit rule as tunable ruleset values |
| combat-system.md | E7 illegal SPECIAL rejected | Server validates legality before storing |
| game-concept.md | Reliable online play on mobile web | Resume tokens, non-paused grace |

## Performance Implications
- **CPU**: one `resolve_turn` per match per turn plus JSON encode/decode; small.
- **Memory**: per match a few KB.
- **Load Time**: none for clients.
- **Network**: tens of messages per match per minute.

## Migration Plan
Greenfield. **Rollback plan**: in-memory-only matches (no persistence) are a valid degraded mode.

## Validation Criteria
- Forged/duplicate/wrong-turn action tests all rejected, state unchanged.
- Kill-and-restart server mid-match; both clients resume and the match completes with identical history.
- Soak test at planned concurrency with turn-resolution p99 under 50 ms (target, to be confirmed by measurement).

## Related
- ADR-0001, ADR-0002, ADR-0004; `design/gdd/combat-system.md` open decision O5
