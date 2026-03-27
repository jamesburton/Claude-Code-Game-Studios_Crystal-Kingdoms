# Game Config

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-26
> **Implements Pillar**: Foundation — all systems read from this

## Overview

Game Config is the central data container that defines the rules and parameters for each match of Crystal Kingdoms. It holds all configurable values — grid size, scoring mode, contagion capture threshold, cursor timing, time limits, win conditions, and player setup. Every gameplay system reads from Game Config at match start; none modify it during play. It exists to make the game data-driven: designers and players can adjust match parameters without touching code.

## Player Fantasy

Game Config is an infrastructure system — players don't feel it directly during gameplay. The emotional target lives in the **pre-match setup**: the feeling of control when customizing a match. "I can make a fast 6x6 deathmatch or a sprawling 12x12 strategic war." The config should feel like a set of clear, meaningful dials — not an overwhelming wall of options. Every setting should produce a noticeably different play experience.

## Detailed Rules

### Core Rules

Game Config is a read-only data object created before match start. Systems read from it; none write to it during play. All values are set via the Menu System (pre-match) or loaded from Settings Manager (persisted defaults).

#### Board Settings

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `grid_size` | int | 8 | 6–12 | Board dimensions (grid_size × grid_size) |
| `wrap_around` | bool | true | — | Whether chains wrap at board edges |
| `cursor_select_captured` | bool | false | — | When true, cursor can spawn on owned cells (not just empty). Enables play to continue when all cells are owned |

#### Scoring Curve System

Many scoring parameters use a **curve selector** rather than a flat value. A curve maps a count (n = 1, 2, 3, ...) to a point value, allowing non-linear scoring progressions.

##### Available Curves

| Curve Name | Formula | Values for n=1,2,3,4,5 | Character |
|------------|---------|------------------------|-----------|
| `POWER_OF_TWO` | 2^(n-1) | 1, 2, 4, 8, 16 | Exponential growth — big rewards for stacking |
| `COUNT` | n | 1, 2, 3, 4, 5 | Linear — predictable, steady growth |
| `FIBONACCI` | fib(n+1) | 1, 2, 3, 5, 8 | Accelerating — rewards streaks without extreme spikes |
| `SQUARE` | (n)² | 1, 4, 9, 16, 25 | Aggressive scaling — dominance snowballs |
| `CUSTOM` | user-defined | a, b, c, d, e, ... | Full control — values entered per step |

##### Scoring Parameter Structure

Each curve-based scoring parameter has three components:

1. **Curve selector** — which progression curve to use
2. **Multiplier** (float, default varies) — scales the curve output
3. **Adjustment** (float, default 0) — additive fine-tuning after multiplication

**Effective value formula:**
```
effective = max(1, round(curve(n) * multiplier + adjustment))
```
- Rounding uses "round half up" (0.5 rounds to 1, 1.5 rounds to 2)
- Minimum effective value is always 1 point (floor clamp)
- The Menu System should display effective values for n=1..5 alongside the selector and multiplier

#### Scoring Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scoring_mode` | enum | BASIC | BASIC or ONLY_CASTLES |
| `lone_castle_scores_zero` | bool | false | When true, capturing an empty castle with 0 adjacent owned castles scores 0 points instead of the minimum 1 |

##### Points: Empty Castle Capture (adjacency-based)

Points awarded when capturing an empty castle. The curve input `n` is the number of adjacent castles already owned by the actor.

| Component | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `points_adjacency_curve` | enum | POWER_OF_TWO | any curve | Progression curve for adjacency bonus |
| `points_adjacency_multiplier` | float | 1.0 | 0.1–10.0 | Multiplier applied to curve output |
| `points_adjacency_adjustment` | float | 0.0 | -10.0–10.0 | Additive adjustment after multiplication |
| `points_adjacency_custom` | int[] | [1,2,3,4] | 1–999 each | Custom values when curve = CUSTOM (index = adjacent count) |

##### Points: Contagion Gain

Points awarded per contagion increment on an enemy castle. The curve input `n` is the new contagion level on that castle for the acting player. In ONLY_CASTLES mode, these are forced to 0.

| Component | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `points_contagion_curve` | enum | COUNT | any curve | Progression curve for contagion scoring |
| `points_contagion_multiplier` | float | 1.0 | 0.1–10.0 | Multiplier applied to curve output |
| `points_contagion_adjustment` | float | 0.0 | -10.0–10.0 | Additive adjustment after multiplication |
| `points_contagion_custom` | int[] | [1,2,3,4] | 1–999 each | Custom values when curve = CUSTOM |

##### Points: Castle Capture (via contagion threshold)

Points awarded when contagion reaches the capture threshold and the castle is seized. The curve input `n` is the number of castles now owned by the actor (including the newly captured one).

**Capture score cap**: The curve input `n` is capped by `capture_threshold`. When `capture_threshold` < 4, `n` is clamped to `capture_threshold`, limiting the maximum capture score. At threshold 4+, the full `n` value is used. This prevents low-threshold configs (easy captures) from also granting huge capture scores — easy to flip means lower reward per flip.

| Component | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `points_capture_curve` | enum | SQUARE | any curve | Progression curve for capture scoring |
| `points_capture_multiplier` | float | 1.2 | 0.1–10.0 | Multiplier applied to curve output |
| `points_capture_adjustment` | float | 0.0 | -10.0–10.0 | Additive adjustment after multiplication |
| `points_capture_custom` | int[] | [1,4,9,16] | 1–999 each | Custom values when curve = CUSTOM |

##### Points: Castle Lost

Points deducted when losing a castle. Bases its value on another scoring parameter's effective value rather than having its own curve.

| Component | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `points_lost_base` | enum | CAPTURE | ADJACENCY, CONTAGION, CAPTURE | Which scorer's effective value to use as base |
| `points_lost_multiplier` | float | 1.5 | 0.1–10.0 | Multiplier applied to the base scorer's value |
| `points_lost_adjustment` | float | 0.0 | -10.0–10.0 | Additive adjustment after multiplication |

Points lost is always negative. The `n` input is the **captured player's** adjacent castle count at the lost castle (not the capturing player's), reflecting the strategic cost of losing a well-connected position.

```
points_lost = -max(1, round_half_up(base_scorer_effective(n) * points_lost_multiplier + points_lost_adjustment))
```

#### Contagion Settings

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `capture_threshold` | int | 3 | 1–10 | Contagion hits needed to capture an enemy castle |

#### Timing Settings

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `cursor_spawn_delay_min` | float | 1.0 | 0.5–5.0 | Minimum seconds before cursor spawns |
| `cursor_spawn_delay_max` | float | 3.0 | 1.0–10.0 | Maximum seconds before cursor spawns |
| `cursor_expire_time` | float | 5.0 | 2.0–15.0 | Seconds before unclaimed cursor expires |
| `chain_step_delay` | float | 0.2 | 0.05–1.0 | Seconds between chain traversal steps (visual pacing) |

#### Match End Settings

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `time_limit` | int | 180 | 60–600 | Match duration in seconds (0 = no limit) |
| `winning_score` | int | 0 | 0–999 | Score to win instantly (0 = disabled) |

#### Constraint Settings

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `max_actions` | int | 0 | 0–999 | Max actions per player per match (0 = unlimited) |
| `max_castles` | int | 0 | 0–144 | Max simultaneously owned castles per player (0 = unlimited) |

#### Player Setup (2–8 players)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `player_id` | string | auto | Unique identifier |
| `player_name` | string | "Player N" | Display name |
| `player_color` | enum | assigned | One of: Blue, Green, Orange, Red, Yellow, Purple, Cyan, Magenta |
| `is_cpu` | bool | false | Whether controlled by AI |
| `cpu_difficulty` | enum | MEDIUM | EASY, MEDIUM, HARD (ignored if not CPU) |
| `input_mode` | enum | FIRE_REQUIRED | FIRE_REQUIRED, DIRECT (ignored if CPU) |

#### Speed Presets (convenience, overrides timing values)

| Preset | cursor_spawn_delay | cursor_expire_time | chain_step_delay |
|--------|-------------------|-------------------|-----------------|
| RELAXED | 2.0–4.0 | 8.0 | 0.4 |
| NORMAL | 1.0–3.0 | 5.0 | 0.2 |
| FAST | 0.5–1.5 | 3.0 | 0.1 |
| FRANTIC | 0.5–1.0 | 2.0 | 0.05 |

### States and Transitions

Game Config is immutable during gameplay. Its lifecycle is:

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Default** | Application launch | User opens match setup | Built-in default values for all parameters |
| **Configuring** | User enters match setup screen | User starts match or loads preset | Values editable via Menu System |
| **Locked** | Match starts | Match ends | Read-only — all systems consume, none modify |
| **Persisted** | User saves settings | Settings loaded or overwritten | Stored via Settings Manager for reuse |

Speed Presets are a convenience that bulk-set timing values. Selecting a preset overwrites `cursor_spawn_delay_min/max`, `cursor_expire_time`, and `chain_step_delay`. After applying a preset, individual timing values can still be tweaked (the preset is a starting point, not a lock).

### Interactions with Other Systems

Game Config is consumed by 8 systems. Data flows **out** only — nothing flows in during gameplay.

| System | Direction | Interface |
|--------|-----------|-----------|
| **Rules Engine** | reads | `scoring_mode`, all `points_*` curve/multiplier/adjustment params, `capture_threshold`, `wrap_around` |
| **Scoring System** | reads | `scoring_mode`, all `points_*` params, `winning_score` — evaluates curves to compute effective point values |
| **Board State** | reads | `grid_size`, `wrap_around` — used at board creation only |
| **Turn Director** | reads | `cursor_spawn_delay_min/max`, `cursor_expire_time`, `chain_step_delay` |
| **Input System** | reads | Player list (player_id, is_cpu) — determines which players need input routing |
| **CPU Controller** | reads | Per-player `cpu_difficulty`, plus `grid_size` and `wrap_around` for spatial reasoning |
| **Match Flow** | reads | `time_limit`, `winning_score`, `max_actions`, `max_castles`, player list — orchestrates match lifecycle |
| **Settings Manager** | reads/writes | Serializes/deserializes the full config for persistence |
| **Menu System** | writes | The only system that modifies config values (pre-match only) |

**Ownership rule**: Game Config owns the data schema. Consumer systems must not cache stale copies — they read from the config reference at point of use. Settings Manager owns persistence. Menu System owns editing.

## Formulas

### Scoring Curve Evaluation

All curve-based scoring uses a single evaluation function:

```
effective(n, curve, multiplier, adjustment) = max(1, round_half_up(curve(n) * multiplier + adjustment))
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n | int | 1+ | gameplay context | Input count (adjacent castles, contagion level, owned castles, etc.) |
| curve | function | — | config selector | One of the 5 curve functions |
| multiplier | float | 0.1–10.0 | config | Scaling factor |
| adjustment | float | -10.0–10.0 | config | Additive fine-tuning |

### Curve Functions

```
POWER_OF_TWO(n) = 2 ^ (n - 1)
COUNT(n)        = n
FIBONACCI(n)    = fib(n + 1)    // sequence: 1, 1, 2, 3, 5, 8... skip first 1
SQUARE(n)       = n ^ 2
CUSTOM(n)       = custom_values[n - 1]   // 0-indexed lookup into user array
```

**Fibonacci lookup table** (precomputed, n=1..12 covers max grid 12x12):

| n | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|----|----|-----|
| fib(n+1) | 1 | 2 | 3 | 5 | 8 | 13 | 21 | 34 | 55 | 89 | 144 | 233 |

### Capture Score Cap

When `capture_threshold` < 4, the curve input `n` for capture scoring is clamped:

```
effective_n = min(n, capture_threshold)    // when capture_threshold < 4
effective_n = n                            // when capture_threshold >= 4
```

This ensures low-threshold games (where castles flip easily) don't also produce massive capture scores. Example with SQUARE curve ×1.2:

| capture_threshold | n (owned) | effective_n | Score |
|-------------------|-----------|-------------|-------|
| 1 | 5 | 1 | 1 |
| 2 | 5 | 2 | 5 |
| 3 | 5 | 3 | 11 |
| 4+ | 5 | 5 | 30 |

### Points Lost Evaluation

Points lost derives from another scorer rather than its own curve:

```
base_value = effective(n, base_scorer_curve, base_scorer_multiplier, base_scorer_adjustment)
points_lost = -max(1, round_half_up(base_value * points_lost_multiplier + points_lost_adjustment))
```

Where `base_scorer` is one of: adjacency, contagion, or capture (default: capture).

### Default Effective Values Preview

With default settings, effective values for n=1..5:

| n | Adjacency (POW2 ×1.0) | Contagion (COUNT ×1.0) | Capture (SQUARE ×1.2) | Lost (from Capture ×1.5) |
|---|------------------------|------------------------|-----------------------|--------------------------|
| 1 | 1 | 1 | 1 | -3 |
| 2 | 2 | 2 | 5 | -8 |
| 3 | 4 | 3 | 11 | -17 |
| 4 | 8 | 4 | 19 | -29 |
| 5 | 16 | 5 | 30 | -45 |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| `grid_size` set to odd number (e.g., 7) | Allowed — 7×7 = 49 cells | No mechanical reason to restrict to even numbers |
| `cursor_spawn_delay_min` > `cursor_spawn_delay_max` | Clamp min to max (treat as equal) | Prevents invalid random range |
| All players are CPU | Allowed — spectator mode | Fun for testing and idle watching |
| All players are human | Allowed — pure local multiplayer | Standard use case |
| Single player (count = 1) | Blocked — minimum 2 players | Game requires at least one opponent |
| 8 players on a 6×6 grid (36 cells) | Allowed but warned in UI — very crowded | Player choice; small board + many players is chaotic but valid |
| `max_castles` set higher than total cells | Treat as unlimited — constraint can never trigger | No harm, just redundant |
| `max_actions` = 1 | Allowed — one-shot mode | Niche but valid variant |
| Custom curve with fewer entries than possible n values | Repeat last value for n beyond array length | Prevents index-out-of-bounds; graceful degradation |
| Custom curve with zero or negative values | Clamp each entry to minimum 1 | Effective value formula already floors at 1, but prevent confusing inputs |
| `multiplier` = 0 | Clamp to 0.1 (minimum range value) | Zero multiplier would make all scores = max(1, adjustment), defeating the curve |
| `winning_score` and `time_limit` both 0 | Blocked — at least one match-end condition required | Prevents infinite matches |
| Speed preset selected, then timing manually tweaked | Manual values override preset; preset indicator shows "Custom" | Preset is a convenience, not a lock |
| `points_lost_base` references itself | Impossible — only ADJACENCY, CONTAGION, CAPTURE are valid selectors | Schema prevents circular reference |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Board State** | Board State reads from this | `grid_size`, `wrap_around` at board creation |
| **Rules Engine** | Rules Engine reads from this | All scoring params, `capture_threshold`, `wrap_around` for chain resolution |
| **Scoring System** | Scoring System reads from this | All `points_*` params, `scoring_mode`, `winning_score` — evaluates curves |
| **Turn Director** | Turn Director reads from this | `cursor_spawn_delay_min/max`, `cursor_expire_time`, `cursor_select_captured`; `max_actions`/`max_castles` for lightweight pre-check (Rules Engine is authoritative) |
| **Input System** | Input System reads from this | Player list — determines which players need input routing |
| **CPU Controller** | CPU Controller reads from this | `cpu_difficulty`, `grid_size`, `wrap_around` for AI decisions |
| **Match Flow** | Match Flow reads from this | `time_limit`, `winning_score`, `max_actions`, `max_castles`, player list |
| **Settings Manager** | Bidirectional | Serializes full config to disk; deserializes to populate config on load |
| **Menu System** | Menu System writes to this | Only system that modifies config values (pre-match) |

**Hard dependencies**: None — Game Config depends on nothing.
**Soft dependencies**: Settings Manager (config works with defaults if persistence is unavailable).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `grid_size` | 8 | 6–12 | More strategic depth, longer matches, more castles to contest | Faster matches, more chaotic, less room for positioning |
| `capture_threshold` | 3 | 1–10 | Castles harder to flip — defensive play rewarded | Castles flip fast — aggressive rushdown dominates |
| `cursor_spawn_delay_min/max` | 1.0/3.0 | 0.5–10.0 | More downtime between actions — strategic breathing room | Relentless pace — reaction speed dominates strategy |
| `cursor_expire_time` | 5.0 | 2.0–15.0 | More forgiving — players can deliberate | Punishes hesitation — forces snap decisions |
| `chain_step_delay` | 0.2 | 0.05–1.0 | Chain traversal feels deliberate and readable | Chain feels instant — harder to follow visually |
| `points_adjacency_curve` | POWER_OF_TWO | any | Exponential curves create territory-building incentives | Linear/count curves make adjacency less important |
| `points_adjacency_multiplier` | 1.0 | 0.1–10.0 | Empty captures worth more — land-grab strategy | Empty captures worth less — contagion/capture focused |
| `points_contagion_multiplier` | 1.0 | 0.1–10.0 | Harassing enemy castles is more rewarding | Harassment is less valuable — incentivizes committing to captures |
| `points_capture_multiplier` | 1.2 | 0.1–10.0 | Big rewards for flipping castles — high-risk high-reward | Captures less decisive — steady play matters more |
| `points_lost_multiplier` | 1.5 | 0.1–10.0 | Losing castles is devastating — defensive play | Losing castles is minor — aggressive play |
| `time_limit` | 180 | 60–600 | Longer matches — more strategic arcs | Short matches — blitz format |
| `max_castles` | 0 (unlimited) | 0–144 | When set, forces players to choose which castles to keep | Unlimited allows snowball domination |
| `max_actions` | 0 (unlimited) | 0–999 | When set, forces efficiency — every action counts | Unlimited favors reaction speed over planning |

**Key interactions:**
- `capture_threshold` × `points_contagion_multiplier`: High threshold + high contagion scoring makes the journey (harassing) more valuable than the destination (capturing)
- `points_capture_multiplier` × `points_lost_multiplier`: Their ratio determines whether the game favors aggression or defense
- `grid_size` × `max_castles`: Small grid + low max castles creates interesting "which castles do I keep?" decisions

### Post-V1 Options (Coming Soon)

These options will appear in the Menu System as greyed-out with a "Coming Soon" label. Implementation details are TBD.

| Parameter | Type | Description | Status |
|-----------|------|-------------|--------|
| `danger_cell_count` | int | Number of hazard cells on the board (blocked, dark, trapped, or reduced-score) | TBD |
| `danger_cell_type` | enum | BLOCKED (impassable), DARK (hidden ownership), TRAPPED (penalty on capture), REDUCED_SCORE (lower point value) | TBD |
| `bonus_cell_count` | int | Number of bonus cells that grant extra rewards | TBD |
| `bonus_cell_values` | config | Point multipliers or special effects for bonus cells | TBD |
| `enable_boosts` | bool | Enable power-up items that spawn during play | TBD |
| `boost_types` | config | Which boosts are active and their spawn rates | TBD |

## Acceptance Criteria

- [ ] All config parameters have correct defaults when no settings are loaded
- [ ] Every parameter respects its defined range — values outside range are clamped
- [ ] Config is immutable during match (no system can modify it after match start)
- [ ] All 5 scoring curves produce correct values for n=1..12
- [ ] `round_half_up` rounding: 0.5 → 1, 1.5 → 2, 2.5 → 3
- [ ] Effective scoring values never fall below 1 (floor clamp)
- [ ] Capture score cap applies when `capture_threshold` < 4, does not apply at 4+
- [ ] Points lost uses the captured player's adjacent count, not the captor's
- [ ] Speed presets correctly overwrite all 4 timing values
- [ ] Manual timing edits after preset selection work and show "Custom" indicator
- [ ] Custom curve arrays handle short arrays (repeat last value) and invalid entries (clamp to 1)
- [ ] `winning_score` = 0 and `time_limit` = 0 simultaneously is blocked
- [ ] Player count enforced: minimum 2, maximum 8
- [ ] No duplicate player colors allowed
- [ ] Config serializes to and deserializes from Settings Manager without data loss
- [ ] Post-V1 options appear greyed out with "Coming Soon" label in Menu System
- [ ] No hardcoded values in implementation — all parameters read from config resource

