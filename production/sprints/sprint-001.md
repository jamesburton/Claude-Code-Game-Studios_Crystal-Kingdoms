# Sprint 1 — Core Logic Layer

## Sprint Goal
Implement the production game logic layer (Game Config, Board State, Rules Engine, Scoring System, Turn Director) as tested GDScript Resources and classes, enabling a headless match to run with scripted inputs and produce correct event logs.

## Capacity
- Total sessions: 5 (estimated)
- Buffer (20%): 1 session reserved for unplanned work
- Available: 4 sessions of focused implementation

## Milestone Context
This is the first production sprint. No prior milestone exists. The target is MVP — a playable local multiplayer game. This sprint covers the Foundation and Core layers from the systems index (systems 1-6 of 10 MVP systems).

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S1-01 | Create production Godot 4.6 project in root directory | Setup | S | None | `project.godot` in root, `src/` directory structure per CLAUDE.md |
| S1-02 | Implement `GameConfig` Resource class | Game Config | S | S1-01 | All parameters from GDD with defaults, `ScorerConfig` sub-resource, `duplicate(true)` works for immutability |
| S1-03 | Implement scoring curve enums and `ScorerConfig` Resource | Scoring System | S | S1-01 | `CurveType` enum, `ScorerConfig` with curve/multiplier/adjustment, `effective()` function, all 5 curves correct for n=1..12 |
| S1-04 | Implement `BoardState` class | Board State | S | S1-02 | Flat array model, `CastleState`, all navigation helpers (`get_neighbor`, `count_adjacent_owned`, `get_cells_in_direction`), wrap-around with `posmod()` |
| S1-05 | Implement `RulesEngine` class | Rules Engine | M | S1-03, S1-04 | Single-cell resolution (4 types), chain traversal, Event struct with `target_points_lost`, scoring integration via `ScorerConfig`, `max_castles` constraint with bonus stack, `lone_castle_scores_zero` |
| S1-06 | Implement `TurnDirector` class | Turn Director | M | S1-04, S1-05 | 6-state turn cycle, cursor spawn/expire, claim racing with pre-check, action hand-off to Rules Engine, `animation_complete` signal support, deterministic RNG with seed |
| S1-07 | Unit tests for `ScorerConfig` | Scoring System | S | S1-03 | All 5 curves verified for n=1..12, `round_half_up` edge cases, multiplier/adjustment combinations, custom array overflow handling |
| S1-08 | Unit tests for `BoardState` | Board State | S | S1-04 | Coordinate conversion, neighbor wrap/no-wrap, adjacency counting, `get_cells_in_direction` with cycle detection |
| S1-09 | Unit tests for `RulesEngine` | Rules Engine | M | S1-05 | All 4 resolution types, chain continuation/stopping rules, contagion capture scoring (capture cap, points lost), max_castles bonus stack FILO, lone_castle_scores_zero |
| S1-10 | Integration test: scripted headless match | All | S | S1-06 | Scripted sequence of force_cursor + submit_action calls, verify scores, ownership, event history, match end conditions |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S1-11 | Install GUT testing framework | Setup | S | S1-01 | GUT addon in project, test runner configured, can execute tests from editor and CLI |
| S1-12 | CPU difficulty profile Resources | CPU Controller | S | S1-02 | `CpuDifficultyConfig` Resource with reaction times, strategic_bias, awareness flags; 3 preset `.tres` files (easy/medium/hard) |
| S1-13 | Speed preset application in GameConfig | Game Config | S | S1-02 | `apply_speed_preset()` method for RELAXED/NORMAL/FAST/FRANTIC; sets timing values correctly |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S1-14 | Port prototype test suite to GUT format | Testing | S | S1-11, S1-09 | All 24 prototype tests converted to GUT `test_` methods with `assert_eq`/`assert_true` |
| S1-15 | Stress test: 100 automated matches | Testing | S | S1-10 | Run 100 scripted matches with varying configs and seeds, >95% complete without errors |

## Carryover from Previous Sprint
N/A — first sprint.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Godot 4.6 API differences from training data | Medium | Medium | Reference `docs/engine-reference/godot/` before using any API; verify with context7 docs |
| GUT framework compatibility with Godot 4.6 | Low | Medium | Check GUT release notes for 4.6 support; fall back to custom test runner (already proven in prototype) |
| Scoring curve complexity creates subtle bugs | Medium | High | Port prototype's 88 passing tests first; add edge case tests for all curve types |
| `Resource.duplicate(true)` behavior for nested Resources | Low | Medium | Test deep copy in S1-02; verify sub-resources are independent after duplication |

## Dependencies on External Factors
- GUT addon must be compatible with Godot 4.6.1 (verify before S1-11)
- No external services or APIs required

## Architecture Reference
- [ADR-0001: Event-Driven Game Loop](../../docs/architecture/adr-0001-event-driven-game-loop.md)
- [ADR-0002: Data-Driven Config via Godot Resources](../../docs/architecture/adr-0002-data-driven-config.md)

## Source Directory Structure (created in S1-01)

```
src/
├── core/
│   ├── game_config.gd          # GameConfig Resource
│   ├── scorer_config.gd        # ScorerConfig sub-Resource
│   └── enums.gd                # CurveType, ScoringMode, Direction, etc.
├── gameplay/
│   ├── board_state.gd          # BoardState class
│   ├── rules_engine.gd         # RulesEngine class
│   └── turn_director.gd        # TurnDirector class
└── data/
    ├── cpu_difficulty_easy.tres
    ├── cpu_difficulty_medium.tres
    └── cpu_difficulty_hard.tres

tests/
├── unit/
│   ├── test_scorer_config.gd
│   ├── test_board_state.gd
│   └── test_rules_engine.gd
└── integration/
    └── test_headless_match.gd
```

## Definition of Done for this Sprint
- [ ] All Must Have tasks (S1-01 through S1-10) completed
- [ ] All tasks pass their acceptance criteria
- [ ] No bugs in core logic (all tests green)
- [ ] Code follows naming conventions from technical-preferences.md
- [ ] Doc comments on all public APIs per coding standards
- [ ] Systems index updated with implementation status
- [ ] Committed to main branch
