# Test Infrastructure

**Engine**: Godot 4.7 (4.7.2 installed in the dev container)
**Test Framework**: gdUnit4 v6.2.3 (vendored at `addons/gdUnit4/`, MIT; its own `test/` folder removed)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-11-14

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic) — one folder per system
  integration/    # Cross-system tests (orchestrator + engine, protocol + server)
  smoke/          # Critical path test list for /smoke-check gate
```

```
production/qa/
  evidence/       # Screenshot logs and manual test sign-off records
```

> Manual evidence lives under `production/qa/evidence/`, not `tests/` — that is
> where `/story-done`, `/smoke-check` and `/test-evidence-review` read it.

## Running Tests

```bash
godot --headless --path . --import
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Run the import first: a fresh clone has no `.godot/` class cache and the runner
exits 1 having run nothing. Exit codes: **0** all passed, **100** a test failed,
**101** all passed but nodes leaked (warning), **105** a test script does not
parse, 103/104 gdUnit4 could not run. The two `ERROR:` lines about the remote
debug port `127.0.0.1:0` are expected. **`No test cases found` with exit 0 is
not a pass** — verified on this project on 2026-11-14 before any test existed.

## Test Naming

Names follow `.claude/rules/test-standards.md`:
- file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`
  — `combat_burst_test.gd` → `test_neutral_attack_hit_has_calibrated_burst_chance()`
- Arrange / act / assert in every test; no filesystem, network or time dependence in unit tests.
- Fixtures: constant files or factory functions under `tests/unit/<system>/fixtures/`, never inline magic numbers (boundary-value tests excepted).

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `production/qa/evidence/` |
| UI | Retained screenshot of each screen touched | `production/qa/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## Installing gdUnit4 (if `addons/gdUnit4/` is ever removed)

1. Open Godot → Asset Store → search "GdUnit4" → install it (or copy `addons/gdUnit4/` from the v6.2.x release)
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓ (already set in `project.godot`)
3. Restart the editor
4. Verify: `res://addons/gdUnit4/bin/GdUnitCmdTool.gd` exists (capital U)

## CI

Tests run on every push to `main` and every pull request. A failed suite blocks merging.
