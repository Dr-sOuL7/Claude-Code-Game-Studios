# Game Concept: SPINFORGE

*Created: 2026-11-09*
*Status: Approved by the owner 2026-11-14 (pillars, visual anchor and recommendations accepted as proposed; **[PROPOSED]** markers are kept to show which items originated as Claude's recommendations). Title: SPINFORGE.*

---

## Elevator Pitch

> It's a turn-based PvP duel game where you build a spinning top from four parts, then out-think a real opponent in secret, simultaneous turns, to burst, ring out or outlast them. It runs in your browser, installs like an app, and no one can buy or grind an advantage.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Turn-based, simultaneous-commit competitive duel / build-and-counter strategy |
| **Platform** | Web (desktop and mobile browsers), installable PWA — built with Godot 4.7 (GDScript), Web export |
| **Target Audience** | Competitive, build-minded players; see Target Player Profile |
| **Player Count** | 2-player duels (online, local, vs AI) plus spectators; designed so other modes can be added |
| **Session Length** | One match ≈ 3–6 minutes **[estimate: ~21 median turns in simulation × turn time]**; sessions 20–60 min |
| **Monetization** | None decided. Hard rule from the owner: nothing that touches stats, rarity or part power. If ever, **[PROPOSED]** cosmetic only (Core visuals) |
| **Estimated Scope** | Large (**[PROPOSED]** 6–10 months solo owner + AI agents to a public launch; unconfirmed — to be set in `/sprint-plan`). First playable milestone is far smaller |
| **Comparable Titles** | Pokémon Showdown (browser competitive turn-based), YOMI Hustle (simultaneous-commit fighting), battling-top toy franchises as theme |

---

## Core Fantasy

You are a blader at the arena rim: you forged your top yourself, and the duel is decided by whether you read your opponent better than they read you. The promise is mastery with no shortcuts: the opponent has exactly the same power budget you do, and the only difference between you is the build you chose and the decisions you make.

---

## Unique Hook

It's like Pokémon Showdown's build-and-counter depth, **and also** every part trades power for power under a fixed budget (all 7,680 builds have the same total stat), so the metagame is about distribution and reads, not rarity. Hidden simultaneous turns make every action a bluff.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** | 3 | Metallic top models, energy trails, impact, burst and ring-out animations driven by engine events |
| **Fantasy** | 5 | Forging and launching your own top; core colour identities |
| **Narrative** | N/A | None at launch; Cores reserve visual identity for the future |
| **Challenge** | 1 | Reading an opponent, bounded randomness, counterplay for every strategy |
| **Fellowship** | 6 | Challenging friends, private invites, spectating |
| **Discovery** | 4 | 512 distinct stat profiles; finding counters and synergies |
| **Expression** | 2 | Build identity (Core, colours, part choices) |
| **Submission** | N/A | Not a relaxation game |

### Key Dynamics (Emergent player behaviours)
- Players model the opponent's build from its visible stats and type, then pick a strategy.
- Players bluff: repeat an action to bait a counter, then break the pattern (Adaptation bonus).
- Players theorycraft counters and share them.
- Players keep several builds for different matchups.

### Core Mechanics (Systems we build)
1. **top construction** — CORE (cosmetic) + BLADE + DISC + TIP, constant stat budgets, derived stats and emergent type.
2. **Simultaneous-commit combat** — five actions, collision, impact, stability, recoil, pressure, energy, burst probability (see `design/gdd/combat-system.md`).
3. **Three finishes** — Burst, Ring-Out, Spin Finish.
4. **Server-authoritative multiplayer** — matchmaking, invitations, timers, reconnection, spectators.
5. **Rankings and history** — outcome-based rating that grants no power.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Free choice of any of 7,680 builds from day one; each turn is a real choice | Core |
| **Competence** | Skill-expressive duels, clear cause and effect, rankings | Core |
| **Relatedness** | Friend challenges, spectating, rivalry | Supporting |

### Player Type Appeal (Bartle Taxonomy)
- [ ] **Achievers** — limited by design (no progression); rankings only
- [x] **Explorers** — build theorycrafting and counter discovery
- [x] **Socializers** — invites, friend duels, spectating
- [x] **Killers/Competitors** — primary: PvP, rankings

### Flow State Design
- **Onboarding curve**: Practice mode vs AI with a guided first match; the Workshop shows live stats and type so a new player learns the stat trade-offs before fighting.
- **Difficulty scaling**: AI difficulty levels; matchmaking by rating (no power gating).
- **Feedback clarity**: every turn emits explained events (who hit, what it cost, what changed); state meters always visible.
- **Recovery from failure**: a match is minutes; rematch and build-swap are one tap. A loss shows why.

---

## Core Loop

### Moment-to-Moment (≈10–20 seconds)
Read the board (energy, stability, pressure, meter, last actions), commit one of five actions in secret, watch the resolution play out. The satisfaction is the reveal: your read was right or wrong.

### Short-Term (3–6 minutes)
One match: ~20–28 turns, ending in Burst, Ring-Out or Spin Finish; result screen explains how it ended. **[estimate]**

### Session-Level (20–60 minutes)
Several matches; adjust the build to what just beat you; try a counter; climb or hold a rating.

### Long-Term Progression
No levels and no unlocks. Long-term growth is player skill, knowledge of the build space, and rating. The game is "done" only when the player stops enjoying the duel.

### Retention Hooks
- **Curiosity**: 512 profiles and 7,680 builds; counters to find.
- **Investment**: saved builds and match history (convenience, never power).
- **Social**: friend challenges, private invites, spectating.
- **Mastery**: rankings, personal win/loss by matchup.

---

## Game Pillars

**[PROPOSED]** — derived directly from the owner's stated principles; they pull against each other where marked.

### Pillar 1: Skill Over Luck
Outcomes come from reading and timing; randomness is small, bounded and visible.

*Design test*: choosing between a wider random range for drama and a narrower one for readability, we choose readability. No mechanic lets a single roll decide a match.

### Pillar 2: Conservation of Power
Every part trades something for something under a fixed budget (Blade 80, Disc 100, Tip 100 = 280 per build). No levels, rarity, upgrades, caps or purchases.

*Design test*: a proposed part that is better in every way is rejected; a new part must redistribute the same budget. Any monetization idea that changes power is rejected without discussion.

### Pillar 3: Counterplay Everywhere (No Dominant Meta)
Every strategy has a counter and extremes carry self-penalties; "balanced" is claimed only with simulation evidence.

*Design test*: any combat change ships only with a simulation report. If one action, part or build rises above the declared bands, we change the rules, not the marketing.

### Pillar 4: Spectacle That Explains
Premium metallic visuals and effects exist to communicate state, never to hide it.

*Design test*: if an effect obscures a number the player needs, the effect is cut or shortened. Effects must also fit the mobile-web budget. This pillar deliberately pulls against raw Sensation: spectacle never outranks clarity.

### Anti-Pillars (What This Game Is NOT)
- **NOT progression, XP or unlocks**: it would turn a skill game into a grind and break Pillar 2.
- **NOT rarity, loot, gacha or paid stats**: pay-to-win is the owner's hard exclusion.
- **NOT real-time reflex combat**: reflexes would reward devices and connection quality over reading (Pillar 1).
- **NOT client-trusting online play**: the server decides every online result; clients only display.
- **NOT dependent on a licensed franchise**: see the naming risk below.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Pokémon Showdown | Browser-first competitive turn-based play, deep team-building, replays | No collecting or growth; the budget is fixed | Validates a large competitive community playing in a browser with no install |
| YOMI Hustle | Simultaneous hidden commits and prediction mind-games | Build-driven stats and slower, spectatable turns | Validates that "read the opponent" is compelling as a core loop |
| Classic spinning-top battles (theme) | The fantasy of a top that wins by burst, ring-out or endurance | Strategic turn-based abstraction, original parts and names | The theme gives instant readability |

**Non-game inspirations**: arena sports broadcasts, machining and metalwork, esports spectator overlays.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 14–35 **[PROPOSED]** |
| **Gaming experience** | Mid-core to hardcore competitive |
| **Time availability** | 5-minute matches between other things; evenings for ladder play |
| **Platform preference** | Phone and desktop browsers |
| **Current games they play** | Pokémon Showdown, chess apps, YOMI Hustle (illustrative) |
| **What they're looking for** | A fair, fast, skill-based duel with build depth and zero grind |
| **What would turn them away** | Pay-to-win, a dominant build, long waits for a match, laggy mobile web |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.7 / GDScript — the owner's choice. GDScript is required because Godot 4 cannot export C# to the web (Godot 4.7 export docs) |
| **Key Technical Challenges** | Web export weight and mobile performance (Compatibility / WebGL 2 renderer); a headless Godot WebSocket server reachable over TLS by browser clients (**NOT SOURCEABLE** in current reference docs — must be proven by a spike); a deterministic pure-GDScript combat engine; balance-simulation speed in GDScript |
| **Art Style** | 3D stylized-realistic metallic, dark arenas, energy effects |
| **Art Pipeline Complexity** | Medium–High, reduced by procedural part meshes generated from stats and 15 core colour palettes |
| **Audio Needs** | Moderate: impact/burst/ring-out SFX, light adaptive music |
| **Networking** | Client-server, dedicated authoritative server, WebSocket |
| **Content Volume** | 24 parts + 15 cores, 3+ arenas, 14 screens; no levels or story |
| **Procedural Systems** | Procedural top geometry from stats (visual only) |

---

## Risks and Open Questions

### Design Risks
- **Balance is not achieved yet**: simulation shows action-level targets nearly met but builds range from 0.02 to 0.86 win rate (combat GDD §12.3). Needs a rule change (O8), not tuning.
- Hidden-commit duels can collapse into solved patterns; needs optimal-play analysis (Phase 6).
- Turn-based duels may feel slow or passive against the "burst" fantasy.

### Technical Risks
- Godot Web export size and frame rate on mid-range phones are unmeasured.
- Headless-server WebSocket over TLS for browser clients is unproven.
- GDScript balance simulation is slower than native; may need sampling or a parallel sim runner.
- Determinism across platforms must be proven by tests, not assumed.

### Market Risks
- **Naming / IP**: the original working title used a third-party registered trademark. **Resolved 2026-11-14: the owner chose the public title SPINFORGE**; the trademarked word must not appear in the product, store listing or marketing. Part and core names are original.
- Niche audience: matchmaking needs enough players online at once (mitigated by AI opponents and private invites).

### Scope Risks
- 14 screens, 3D visuals, authoritative multiplayer, accounts, history and rankings are a lot for a solo builder.
- Mitigation: the staged milestones below; online comes after the local game is proven.

### Open Questions
- Which rule fixes the component imbalance (O8)?
- What turn timer and timeout rule are fair (O5)?
- Does the TLS WebSocket server work with a Godot Web client? (spike)
- What frame rate and download size does a Web export reach on a typical phone? (spike)

---

## MVP Definition

**Core hypothesis**: Simultaneous hidden commits between five actions create tense, readable duels where build choice and reads decide the winner, in a browser.

**Required for MVP (first playable milestone)**:
1. Forge (workshop): pick Core/Blade/Disc/Tip, see derived stats and type live.
2. Combat engine (pure GDScript, deterministic, tested) with the five actions and three finishes.
3. Local Versus (hidden-commit pass-the-device) in a browser build.
4. Battle arena with events animated and a state HUD; result screen explaining the finish.
5. Headless test harness and the balance simulator running the same engine.

**Explicitly NOT in MVP** (deferred):
- Accounts, persistence, matchmaking, online play, spectating, rankings, admin.
- AI opponents, polished 3D art, PWA install polish.

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | All 24 parts, 1 arena | Workshop, engine, Local Versus, result screen | TBD in `/sprint-plan` |
| **Vertical Slice** | Polished arena, procedural parts, VFX | Practice vs AI, full match flow, mobile-web perf pass | TBD |
| **Alpha** | All screens, rough art | Accounts, online PvP, matchmaking, invites, reconnection, history | TBD |
| **Full Vision** | Final art, several arenas | Spectator, rankings, admin/config, PWA polish, live balance | TBD |

---

## Visual Identity Anchor

**[PROPOSED]** — art-director gate skipped (`lean` mode); owner to confirm or replace.

**Direction: Neon Forge.** *Metal you can feel, light that tells you what's happening.*

- **Light carries meaning**: each top glows in its Core's two-tone palette; glow intensity maps to energy and state. *Design test*: an effect with no gameplay meaning is removed.
- **Dark arena, bright information**: a dark, high-contrast arena keeps the HUD readable on phones. *Design test*: HUD text meets contrast requirements on the brightest effect.
- **Silhouette tells the build**: procedural meshes expose stats (blade reach, disc mass, tip shape). *Design test*: two builds with different stats must not look the same.

**Colour philosophy**: dark neutrals for arena and UI; the 15 Core palettes (cyan/white, red/black, purple/silver …) are the only saturated colours, so a Core colour always means "this player". Never colour-only signals: pair every state colour with a shape or icon (colourblind safety).

---

## Next Steps

- [ ] Owner confirms or edits this concept (pillars, visual anchor, timeline, naming)
- [ ] `/art-bible` — before asset work (visual-asset stories exist)
- [ ] `/design-review design/gdd/game-concept.md`
- [ ] `/map-systems` — systems index and dependencies
- [ ] `/design-system` for each system; finish and approve `combat-system.md` first
- [ ] `/create-architecture`, then `/architecture-decision` per decision
- [ ] `/architecture-review`, `/gate-check`, then `/create-epics` and `/create-stories`
