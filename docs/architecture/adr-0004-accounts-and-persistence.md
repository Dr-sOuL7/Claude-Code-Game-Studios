# ADR-0004: Accounts and Persistence — Supabase Auth + Postgres, Server-Only Writes

## Status

Proposed

> Only the user (or `technical-director` on the user's explicit confirmation) may set `Accepted`.

## Date

2026-11-09

## Last Verified

2026-11-09 — **Supabase specifics (endpoints, CORS, RLS, service-role behaviour) were NOT verified this run.** They come from the model's prior knowledge and must be checked against the Supabase documentation before this ADR is Accepted. Godot-side browser limits were verified (Godot 4.7 web export docs).

## Decision Makers

Owner (delegated to Claude for a proposal); technical-director review pending.

## Summary

Accounts and durable data use Supabase (Auth + Postgres). Players sign up and sign in from the browser straight to Supabase Auth; only the headless game server writes match, build-sync and rating data, using a service key kept in server environment variables.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH |
| **References Consulted** | Godot 4.7 "Exporting for the Web" (HTTP restrictions: same-origin policy, no chunked responses, host verification cannot be disabled; `user://` persistence needs IndexedDB and fails in private browsing) |
| **Post-Cutoff APIs Used** | None (`HTTPRequest`, `JSON`) |
| **Verification Required** | (1) Browser `HTTPRequest` to Supabase Auth succeeds under CORS from the production origin; (2) server-side `HTTPRequest` with the service key; (3) Supabase terms and free-tier limits for the expected load |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 |
| **Enables** | History, Rankings, Admin, Build persistence |
| **Blocks** | Accounts epic |
| **Ordering Note** | Local Versus and Practice need no account and must not depend on this ADR |

## Context

### Problem Statement
Persistent accounts, saved builds, match history, rankings and admin configuration are required. The owner listed Supabase as acceptable. Browser `user://` storage is not durable (IndexedDB can be evicted or blocked, per the Godot web docs), so it cannot hold accounts.

### Constraints
- The game server is a Godot headless process; it has no native Postgres driver, so database access is via HTTP.
- The browser can only use HTTP requests and WebSocket (Godot web docs) and is subject to the same-origin policy.
- Passwords must never pass through the game server or be stored by us.
- No stat, rarity or progression data may exist (design pillar 2), so the schema carries identity, builds, results and ratings only.

## Decision

```
Browser ── HTTPS ──► Supabase Auth (sign up / sign in / refresh)  ── JWT ──┐
Browser ── WSS  ──► Game server: hello{JWT} ── verifies JWT ◄────────────┘
Game server ── HTTPS (service key) ──► Supabase Postgres (REST)
```

### Data model (initial; migrations in `supabase/migrations/`)
- `profiles(id uuid PK = auth user, display_name unique, created_at)`
- `builds(id, owner_id, name, core, blade, disc, tip, created_at)` — a build is four part ids; there are no per-build stats columns.
- `matches(id, ruleset_version, seed, mode, player_a, player_b, build_a, build_b, winner, finish_type, turns, started_at, ended_at)`
- `match_turns(match_id, turn, action_a, action_b, events, PRIMARY KEY(match_id, turn))`
- `ratings(player_id, mode, rating, deviation, games, updated_at)`
- `rulesets(version PK, data jsonb, created_at, created_by)` — immutable after first use.
- `admin_roles(user_id, role)` — gates admin tools and ruleset publication.

### Security model
- **Row-Level Security on every table.** Clients may read their own rows and public views (leaderboard, finished matches); they may not insert/update match, turn or rating rows. The only client-writable data are `profiles.display_name` and `builds` for their own `owner_id` (validated for legal part ids by a database check constraint).
- The **service key** is a server environment variable; it must never be exported into the Web build, committed, or logged.
- The server validates the client JWT in `hello` before serving a socket. PROPOSED method: call the Supabase Auth user endpoint with the token and cache the result for the token's lifetime (avoids implementing JWT signature verification in GDScript). To be verified.
- Display names are moderated server-side (length, charset, reserved words).
- Account deletion removes `profiles` and `builds`; matches keep anonymized participants.

### Implementation Guidelines
- Auth screens **must** call Supabase from the client; the game server **must never** see a password.
- All writes to `matches`, `match_turns`, `ratings` **must** come from the server only.
- Schema changes **must** be migrations in `supabase/migrations/`, applied by CI; no manual edits in production.
- Secrets **must** be environment variables only (server); the Web build contains only the public project URL and anon key.
- Rating: Elo or Glicko-2 (decision deferred to the rankings story). Ratings **must not** gate content or modify any stat.

## Alternatives Considered

### Alternative 1: Self-hosted Postgres + custom authentication
- **Pros**: No vendor dependency.
- **Cons**: Auth is high-risk to write; more operations work for a solo owner.
- **Rejection Reason**: Not worth the risk or time; the schema stays plain SQL so migration away stays possible.

### Alternative 2: Firebase / NoSQL
- **Pros**: Fast start.
- **Cons**: Relational queries for history and leaderboards are awkward; the owner specified PostgreSQL.
- **Rejection Reason**: PostgreSQL requirement.

### Alternative 3: Local-only storage (`user://` in the browser)
- **Pros**: No backend.
- **Cons**: Evictable, absent in private browsing (Godot web docs), not cross-device.
- **Rejection Reason**: Cannot satisfy persistent accounts.

## Consequences

### Positive
- Little custom auth code; a SQL schema we can export.
- Server-only writes keep results tamper-proof.

### Negative
- Vendor dependency and free-tier limits (unverified).
- Every persistence call is an HTTP round trip (hence write-behind in ADR-0003).

### Neutral
- Local Versus and Practice work offline without an account.

## Risks
- CORS or cookie behaviour blocks browser auth calls. *Mitigation*: first spike from the real origin.
- Service key leak. *Mitigation*: server-only env var, secret scanning in CI.
- Token validation per connection adds latency. *Mitigation*: cache.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-concept.md | Persistent accounts and builds; history; rankings; admin config | Tables above |
| combat-system.md | Rulesets are versioned data (Tuning Knobs) | `rulesets` table, immutable once used |
| game-concept.md (Pillar 2) | No power progression or paid stats | Schema has no stat/progression/rarity columns |

## Performance Implications
- **CPU**: negligible on the client; server JSON encode/decode.
- **Memory**: negligible.
- **Load Time**: auth round trip at sign-in.
- **Network**: one HTTPS call per persisted turn per match, batched where possible.

## Migration Plan
Greenfield. **Rollback plan**: SQL migrations are reversible by down-migrations; the service layer is a thin wrapper so the REST backend can be swapped for plain Postgres.

## Validation Criteria
- Anonymous and signed-in clients cannot write match, turn or rating rows (tests against RLS).
- Sign-up, sign-in, refresh and sign-out work from the production origin on desktop and mobile browsers.
- A deleted account leaves no personal data.

## Related
- ADR-0002, ADR-0003, ADR-0005
