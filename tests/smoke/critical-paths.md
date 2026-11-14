# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)
1. Web export loads to the shell without a console error (desktop Chromium)
2. The Forge (workshop) opens and a build can be assembled
3. A Local Versus match can be started from the shell

## Core Mechanic (update per sprint)
4. One full Local Versus match resolves to a result screen with the finish type shown
5. Engine unit suite passes headless (`tests/unit/combat/`)

## Data Integrity
6. Ruleset version shown on the result screen matches `assets/data/combat/` (once persisted)
7. Saved build reloads with identical derived stats (once accounts exist)

## Performance
8. Arena scene holds the target frame budget on a mid-range phone (once the 3D arena exists)
9. No memory growth over 5 minutes of Local Versus play (once the core loop is implemented)
