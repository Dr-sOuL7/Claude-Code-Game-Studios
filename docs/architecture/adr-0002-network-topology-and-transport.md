# ADR-0002: Network Topology and Transport — Web Client, Headless Godot Server, WebSocket

## Status

Accepted

> Only the user (or `technical-director` on the user's explicit confirmation) may set `Accepted`.

## Date

2026-11-09 (proposed); accepted 2026-11-14

## Last Verified

2026-11-09 (Godot 4.7 pages: Exporting for the Web, WebSocketPeer, Using WebSockets, Exporting for dedicated servers — all fetched this run)

## Decision Makers

Owner (accepted 2026-11-14, on Claude's recommendation); authored by Claude.

## Summary

Browser clients (Godot Web export) connect over `wss://` WebSocket to a separate headless Godot dedicated server that owns all online match state. Messages are versioned JSON text frames over `WebSocketPeer` — not Godot RPC — and TLS terminates at the hosting platform's proxy.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 |
| **Domain** | Networking |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH |
| **References Consulted** | Godot 4.7 docs (Exporting for the Web; WebSocketPeer class; Using WebSockets; Exporting for dedicated servers); `docs/engine-reference/godot/modules/networking.md` |
| **Post-Cutoff APIs Used** | `WebSocketPeer` is long-standing; `StreamPeerTLS.accept_stream` fallback path; none are new in 4.5–4.7 as far as the 4.7 pages show. Not independently checked against the 4.4→4.7 changelog |
| **Verification Required** | (1) Headless Linux server accepts a Chromium Godot-Web client over a real `wss://` URL behind the chosen host's proxy; (2) concurrent-connection capacity of one headless server (NOT SOURCEABLE — load test); (3) reconnect after a backgrounded tab on iOS Safari and Android Chrome |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 |
| **Enables** | ADR-0003, ADR-0004, ADR-0005 |
| **Blocks** | Online PvP, Matchmaking, Spectator epics |
| **Ordering Note** | A connect-and-echo spike must pass before this is Accepted |

## Context

### Problem Statement
Online matches must be server-authoritative and playable from a browser (including phones). We need a transport the browser can use, a server that can run the same combat engine, and a protocol that survives reconnects and version changes.

### Constraints (sourced from the Godot 4.7 docs)
- Web exports support only HTTP client/requests, WebSocket (client) and WebRTC; low-level networking such as ENet is not available in browsers.
- `WebSocketPeer.accept_stream()` (the server side) is **not supported in Web exports** — the server must be a native/headless build.
- `handshake_headers` is **not supported in Web exports**, so the browser cannot send an auth header during the handshake.
- `heartbeat_interval` has **no effect in Web exports**.
- When the browser tab is not the active tab, `_process()` stops, "which can cause networked games to disconnect".
- A page served over HTTPS needs `wss://` (mixed content); the host in `wss://` must match the certificate's name, not an IP.
- Default buffers: inbound/outbound 65,535 bytes, 4,096 queued packets.
- WebSocket is TCP-based: "good for turn-based games", "not good for real-time applications" — acceptable here (turn-based).
- The WebSocket implementation "is compatible with the High-Level Multiplayer".

### Requirements
- Server-authoritative; hidden actions never sent to the opponent or spectators before resolution.
- Reconnection of a dropped client to an active match.
- Protocol versioning so a stale cached client (PWA service worker) is detected and refreshed.

## Decision

```
 Browser (Godot Web, single-thread, Compatibility)
        │  wss://game.example/ws   (TLS terminated by the host's proxy)
        ▼
 Host proxy ──► ws:// (plain, private network) ──► Headless Godot server (Linux, `dedicated_server` export)
                                                      │ HTTPRequest (service key)
                                                      ▼
                                                  Supabase (ADR-0004)
```

### Key Interfaces
Envelope (JSON text frame): `{ "v": <protocol int>, "t": "<type>", "id": <client msg id>, ... }`.
Client→server: `hello{token}`, `queue_join`, `queue_leave`, `challenge{to}`, `invite_create`, `invite_join{code}`, `build_lock{build}`, `action{match_id, turn, action}`, `resume{match_id, resume_token}`, `spectate{match_id}`, `ping`.
Server→client: `hello_ok`, `error{code}`, `match_found`, `turn_open{turn, deadline_ms}`, `opponent_committed`, `turn_resolved{events, public_state}`, `match_finished{result}`, `state_snapshot`, `pong`.
Schemas are documented in `docs/architecture/protocol.md` (to be written with the first networking story) and validated on the server for every inbound frame.

### Implementation Guidelines
- Transport **must** be `WebSocketPeer` text frames carrying JSON. The Godot RPC/`MultiplayerAPI` **must not** be used for game messages.
- The server **must** listen on a plain TCP port with `TCPServer` + `WebSocketPeer.accept_stream()` and let the hosting platform terminate TLS. The documented alternative (`StreamPeerTLS.accept_stream` then `WebSocketPeer.accept_stream`) stays available as a fallback, unverified.
- Authentication **must** happen in the first client message (`hello{token}`); the server **must** close connections that do not send a valid `hello` within a short timeout.
- Because heartbeats do nothing in the browser, the application **must** implement `ping`/`pong` with server-side idle timeouts.
- Every inbound message **must** be size-limited, rate-limited, schema-validated and version-checked; unknown `v` ⇒ `error{client_outdated}` and the client forces a refresh.
- Messages **must** stay well under the 65,535-byte buffer (design target: < 16 KB); larger payloads (e.g. replay download) use HTTP, not the match socket.
- The server **must not** send a player's pending action to anyone before the turn resolves.
- The same Godot project may host client and server; the server entry **must** be selected by the `dedicated_server` feature tag or `--headless` (both documented), never by a client-visible switch.

## Alternatives Considered

### Alternative 1: Godot high-level multiplayer RPC over WebSocketMultiplayerPeer
- **Pros**: Least code; supported with WebSocket.
- **Cons**: RPCs bind to node paths shared by client and server scenes; peer IDs change on reconnect; versioning and hidden-information filtering are implicit.
- **Rejection Reason**: Reconnection and versioning are core requirements; explicit messages make them testable.

### Alternative 2: WebRTC data channels / peer-to-peer
- **Pros**: Lower latency.
- **Cons**: Needs signalling and NAT traversal; peers would hold state, which defeats authority.
- **Rejection Reason**: Turn-based play does not need low latency; authority is a hard requirement.

### Alternative 3: Non-Godot server (e.g. Node/TypeScript)
- **Pros**: Mature WebSocket ecosystem.
- **Cons**: Cannot run the GDScript combat engine; would duplicate it (ADR-0001 rejects this).
- **Rejection Reason**: One engine implementation.

### Alternative 4: Terminate TLS inside Godot
- **Pros**: No dependency on a proxy.
- **Cons**: Certificate management in a game server; no verified recipe this run.
- **Rejection Reason**: Hosts already terminate TLS; kept as a fallback.

## Consequences

### Positive
- Reconnect, versioning and hidden-information rules are explicit and testable.
- The server reuses ADR-0001's engine unchanged.

### Negative
- We own a protocol (schemas, versioning, validation).
- A single headless process has unknown capacity; scale-out requires match-sticky routing (out of scope for v1).

### Neutral
- Local Versus and Practice use no network.

## Risks
- Mobile Safari WebSocket/WebGL behaviour (docs warn Safari has several WebGL 2.0 issues). *Mitigation*: test on iOS early; first spike runs there.
- Tab backgrounding drops sockets. *Mitigation*: reconnect-first design (ADR-0003); never penalize a brief disconnect.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-system.md | Hidden commit; neither player sees the opponent's action | Message set exposes only `opponent_committed` before `turn_resolved` |
| game-concept.md | Server-authoritative online PvP in a browser | Headless server + WSS client |

## Performance Implications
- **CPU**: server main thread polls all sockets each frame; cost scales with connections (unmeasured).
- **Memory**: per-connection buffers ~64 KiB each direction by default.
- **Load Time**: none for the client beyond the connection handshake.
- **Network**: tiny per-turn JSON.

## Migration Plan
Greenfield. **Rollback plan**: the protocol is versioned; a failed transport approach is replaced behind the same message set.

## Validation Criteria
- Spike: headless server + Web client exchange `hello`/`ping` over `wss://` behind the real host, on desktop Chromium, Android Chrome and iOS Safari.
- Load test: N simultaneous matches at the planned peak with stable tick time.

## Related
- ADR-0001, ADR-0003, ADR-0004, ADR-0005
- Sources: Godot 4.7 docs — `tutorials/export/exporting_for_web`, `classes/class_websocketpeer`, `tutorials/networking/websocket`, `tutorials/export/exporting_for_dedicated_servers`
