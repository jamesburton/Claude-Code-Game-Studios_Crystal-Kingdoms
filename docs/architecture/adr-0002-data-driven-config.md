# ADR-0002: Data-Driven Configuration via Godot Resources

## Status
Accepted

## Date
2026-03-27

## Context

### Problem Statement
Crystal Kingdoms has a rich configuration surface: grid size, scoring curves with multipliers and adjustments, timing presets, player setup, constraint limits, and CPU difficulty profiles. These values must be adjustable without code changes, persistable across sessions, and readable by 8+ systems at runtime. We need a configuration architecture that is data-driven, type-safe, and integrates cleanly with Godot 4.6.

### Constraints
- Godot 4.6 with GDScript as primary language
- Configuration must be immutable during gameplay (locked at match start)
- Must support serialization for settings persistence
- CPU difficulty profiles are tuned independently from main game config
- Scoring uses non-linear curves (power-of-two, fibonacci, square, custom) — not simple flat values

### Requirements
- All gameplay values configurable without touching code
- Type-safe access (no string-key lookups for core params)
- Serializable for Settings Manager persistence
- Menu System can read/write config values pre-match
- 8+ systems read from config at runtime

## Decision

**Use Godot Resource files (`.tres`) for all configuration data.**

### Game Config as a Custom Resource

Game Config is implemented as a Godot `Resource` subclass with exported properties. This gives us:
- Type-safe properties with editor validation
- Built-in serialization (`ResourceSaver` / `ResourceLoader`)
- Inspector editing during development
- Deep copy via `Resource.duplicate()` for immutability enforcement

```
GameConfig (Resource)
├── Board Settings (grid_size, wrap_around, cursor_select_captured)
├── Scoring Settings (scoring_mode, lone_castle_scores_zero)
│   ├── AdjacencyScorer (Resource) — curve, multiplier, adjustment, custom_values
│   ├── ContagionScorer (Resource) — curve, multiplier, adjustment, custom_values
│   ├── CaptureScorer (Resource) — curve, multiplier, adjustment, custom_values
│   └── LostScorer — base_selector, multiplier, adjustment
├── Contagion Settings (capture_threshold)
├── Timing Settings (spawn delays, expire time, chain step delay)
├── Match End Settings (time_limit, winning_score)
├── Constraint Settings (max_actions, max_castles)
└── Players (Array of PlayerConfig Resources)
```

### Scoring Curves as Sub-Resources

Each scoring parameter (adjacency, contagion, capture) is its own sub-Resource containing curve type, multiplier, adjustment, and custom values array. This keeps the scoring configuration modular and avoids a flat list of 15+ scoring fields on the main config.

### CPU Difficulty as Separate Resources

CPU difficulty profiles are stored as standalone Resource files:
- `res://data/cpu_difficulty_easy.tres`
- `res://data/cpu_difficulty_medium.tres`
- `res://data/cpu_difficulty_hard.tres`

Game Config's `cpu_difficulty` enum selects which resource to load. This allows difficulty tuning independently of game config, and custom difficulty profiles in the future.

### Immutability at Match Start

At match start, Match Flow calls `config.duplicate(true)` (deep copy) to create a locked snapshot. All systems read from this snapshot during gameplay. The Menu System writes to the original config object pre-match. This prevents mid-game config changes without explicit locking code.

### Key Interfaces

```gdscript
class_name GameConfig extends Resource

@export var grid_size: int = 8
@export var wrap_around: bool = true
@export var cursor_select_captured: bool = false
@export var scoring_mode: ScoringMode = ScoringMode.BASIC
@export var lone_castle_scores_zero: bool = false
@export var adjacency_scorer: ScorerConfig
@export var contagion_scorer: ScorerConfig
@export var capture_scorer: ScorerConfig
# ... etc

class_name ScorerConfig extends Resource

@export var curve: CurveType = CurveType.COUNT
@export var multiplier: float = 1.0
@export var adjustment: float = 0.0
@export var custom_values: Array[int] = []
```

### Architecture Diagram

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ default.tres │     │ saved.tres   │     │ cpu_easy.tres│
│ (defaults)   │     │ (persisted)  │     │ cpu_med.tres │
└──────┬───────┘     └──────┬───────┘     │ cpu_hard.tres│
       │                    │              └──────┬───────┘
       ▼                    ▼                     │
  ┌─────────────────────────────┐                 │
  │      Menu System            │◄────────────────┘
  │  (reads/writes pre-match)   │
  └─────────────┬───────────────┘
                │ config.duplicate(true)
                ▼
  ┌─────────────────────────────┐
  │   Locked Config Snapshot    │ (immutable during match)
  └─────────────┬───────────────┘
                │ read-only access
    ┌───────────┼───────────┬────────────┐
    ▼           ▼           ▼            ▼
 Rules      Board       Turn         CPU
 Engine     State       Director     Controller
            (+ 4 more systems)
```

## Alternatives Considered

### Alternative 1: JSON/Dictionary Configuration
- **Description**: Store config as JSON files, parse into Dictionaries at load time
- **Pros**: Human-readable, easy to edit externally, version-control friendly
- **Cons**: No type safety (string keys, runtime type errors); no editor integration; manual serialization; deep nesting is fragile
- **Rejection Reason**: GDScript Dictionaries lose type safety. Godot Resources provide typed exports, editor validation, and built-in serialization — all of which JSON requires manual implementation.

### Alternative 2: Autoload Singleton with Exported Variables
- **Description**: A single autoload node with all config as `@export` properties
- **Pros**: Globally accessible; simple; works with Godot inspector
- **Cons**: Cannot deep-copy for immutability; singleton makes testing harder (global state); doesn't serialize naturally for persistence; all config in one massive script
- **Rejection Reason**: Singletons resist immutability and testability. Resources can be duplicated, passed as parameters, and swapped for test fixtures.

### Alternative 3: ConfigFile (INI-style)
- **Description**: Use Godot's `ConfigFile` class for key-value storage
- **Pros**: Built into Godot; simple read/write; human-readable format
- **Cons**: No type safety; flat key-value structure doesn't handle nested scoring configs well; no editor integration
- **Rejection Reason**: Scoring curves have nested structure (curve type + multiplier + adjustment + custom array) that doesn't map well to flat key-value pairs.

## Consequences

### Positive
- Type-safe configuration with compile-time property access
- Built-in Godot editor support for tuning during development
- Deep copy via `duplicate(true)` enforces match-time immutability cleanly
- Sub-resources keep scoring config modular and reusable
- Resource files are version-control friendly (`.tres` is text-based)
- Settings Manager implementation is trivial (`ResourceSaver`/`ResourceLoader`)

### Negative
- Resources require class definitions — adding a new config field means editing both the Resource class and any UI that exposes it
- `.tres` files are Godot-specific — not portable to other engines (acceptable for this project)
- Deep copy has a small cost at match start (negligible for config-sized data)

### Risks
- **Risk**: Resource class changes break saved `.tres` files
  - **Mitigation**: Use `@export` with defaults; Godot handles missing properties gracefully on load. Add version field for migration if needed.
- **Risk**: Developers accidentally read the mutable pre-match config instead of the locked snapshot
  - **Mitigation**: Match Flow passes the locked snapshot explicitly; the mutable config is not exposed during gameplay.

## Performance Implications
- **CPU**: Zero per-frame cost. Config is read at match start and on specific events, not polled.
- **Memory**: ~2KB for the full config tree including sub-resources. Negligible.
- **Load Time**: <1ms to load a `.tres` file. Negligible.

## Migration Plan
No existing code to migrate — greenfield decision.

## Validation Criteria
- All 8+ consuming systems read from the locked config snapshot (not the mutable original)
- Config modifications in Menu System do not affect an active match
- Settings Manager can save/load config without data loss (round-trip test)
- Adding a new config field requires only: add `@export` property + add UI in Menu System
- CPU difficulty profiles load correctly from standalone Resource files

## Related Decisions
- [ADR-0001: Event-Driven Game Loop](adr-0001-event-driven-game-loop.md)
- [Game Config GDD](../../design/gdd/game-config.md)
- [Scoring System GDD](../../design/gdd/scoring-system.md)
- [CPU Controller GDD](../../design/gdd/cpu-controller.md)
