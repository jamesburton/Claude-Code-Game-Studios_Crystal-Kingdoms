# Board State

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-26
> **Implements Pillar**: Foundation — grid data model all gameplay systems operate on

## Overview

Board State is the grid data model that represents the game board at any point during a match. It holds the ownership and contagion data for every cell, the cursor position, and provides helper functions for grid navigation (adjacency, direction traversal, wrap-around). All gameplay systems read from Board State; only the Rules Engine and Turn Director modify it. It is created once at match start from Game Config and mutated through deterministic operations.

## Player Fantasy

Board State is pure infrastructure — players never interact with it directly. Its quality is felt indirectly: when the board "just works" — castles change color smoothly, chains traverse correctly, adjacency counts are always right. The player fantasy it serves is the board itself feeling like a living, contested territory where every cell matters.

## Detailed Rules

### Core Rules

#### Data Model

The board is a flat array of `CastleState` objects, indexed 0 to `grid_size² - 1`. Row-major order: index = `row * grid_size + col`.

**CastleState:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `owner` | PlayerId \| null | null | Which player owns this castle, or null if empty |
| `contagion` | Dictionary<PlayerId, int> | {} | Per-player contagion counters on this castle |

**BoardState:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `size` | int | from config | Grid dimension (size × size) |
| `wrap_around` | bool | from config | Whether navigation wraps at edges |
| `cells` | CastleState[] | all empty | Array of length size² |
| `cursor_index` | int \| -1 | -1 | Grid index of active cursor (-1 = no cursor) |
| `cursor_active` | bool | false | Whether a cursor is currently claimable |

#### Grid Navigation Helpers

These are pure functions on the board — no side effects.

| Function | Signature | Description |
|----------|-----------|-------------|
| `index_to_coords(index)` | int → (row, col) | Convert flat index to row/col |
| `coords_to_index(row, col)` | (int, int) → int | Convert row/col to flat index |
| `get_neighbor(index, direction)` | (int, Direction) → int \| -1 | Get adjacent cell index in direction. Returns -1 if off-edge and wrap_around is false |
| `get_adjacent_indices(index)` | int → int[] | All orthogonal neighbors (up to 4, or exactly 4 with wrap) |
| `count_adjacent_owned(index, player_id)` | (int, PlayerId) → int | Count of orthogonal neighbors owned by player |
| `get_cells_in_direction(index, direction)` | (int, Direction) → int[] | Ordered list of cell indices from start (exclusive — start cell not included) along direction, stopping at board edge (no wrap) or when returning to start cell (wrap). Used by CPU Controller for chain lookahead |

**Direction** enum: `UP`, `DOWN`, `LEFT`, `RIGHT` (orthogonal only, no diagonals — per resolved rules).

#### Wrap-Around Navigation

When `wrap_around` is true:
- Moving UP from row 0 → row (size - 1), same column
- Moving DOWN from row (size - 1) → row 0, same column
- Moving LEFT from col 0 → col (size - 1), same row
- Moving RIGHT from col (size - 1) → col 0, same row

When `wrap_around` is false:
- Moving off any edge returns -1 (no valid cell)

#### Board Creation

At match start:
1. Read `grid_size` and `wrap_around` from Game Config
2. Allocate `grid_size²` cells, all with `owner = null`, `contagion = {}`
3. Set `cursor_index = -1`, `cursor_active = false`
4. Board is ready for play

No pre-placed castles — all cells start empty. Players claim territory through gameplay.

### States and Transitions

Board State itself doesn't have lifecycle states — it exists for the duration of a match. Individual cells transition between ownership states:

| Cell State | Entry Condition | Exit Condition |
|------------|----------------|----------------|
| **Empty** (owner = null) | Board creation / owner destroys own castle | Any player captures it |
| **Owned** (owner = player) | Player captures empty cell or captures via contagion | Another player captures via contagion / owner destroys it |

Contagion on a cell:
- Incremented when an enemy player acts on this cell
- Reset (for all players) when the cell is captured via contagion threshold
- Preserved when the owner destroys their own castle (contagion stays, ownership clears)

Cursor:

| Cursor State | Entry Condition | Exit Condition |
|-------------|----------------|----------------|
| **Inactive** (cursor_index = -1) | Match start / cursor claimed or expired | Turn Director spawns cursor |
| **Active** (cursor_index ≥ 0, cursor_active = true) | Turn Director places cursor on random empty cell | Player claims it / cursor expires |
| **Claimed** (cursor_active = false) | Player acts on cursor | Action chain completes, cursor returns to Inactive |

**Cursor timing rule**: The cursor disappears immediately when a player claims it. The respawn delay timer does NOT start until the entire action chain has completed. This ensures no board state changes occur while a cursor is awaiting an action, and gives players a moment to observe chain results before the next cursor appears.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Game Config** | Board State reads | `grid_size`, `wrap_around` at creation only |
| **Rules Engine** | Rules Engine reads + writes | Reads cell ownership/contagion to resolve actions; writes ownership changes, contagion increments, resets |
| **Turn Director** | Turn Director reads + writes | Writes `cursor_index`/`cursor_active` on spawn/claim/expire; reads cell state to find valid spawn targets |
| **Scoring System** | Scoring System reads | Reads `count_adjacent_owned()` for adjacency scoring |
| **CPU Controller** | CPU Controller reads | Reads full board for AI decision-making (ownership map, contagion levels, adjacency) |
| **Board Renderer** | Board Renderer reads | Reads full board each frame for visual display |

**Mutation rule**: Only Rules Engine and Turn Director may mutate Board State. All other systems have read-only access. Mutations produce events (defined by Rules Engine) for the Renderer and other observers.

## Formulas

### Index ↔ Coordinate Conversion

```
index_to_coords(index):
    row = index / size    // integer division
    col = index % size
    return (row, col)

coords_to_index(row, col):
    return row * size + col
```

### Wrapped Neighbor Calculation

```
get_neighbor(index, direction):
    (row, col) = index_to_coords(index)
    match direction:
        UP:    new_row = row - 1, new_col = col
        DOWN:  new_row = row + 1, new_col = col
        LEFT:  new_row = row,     new_col = col - 1
        RIGHT: new_row = row,     new_col = col + 1

    if wrap_around:
        new_row = posmod(new_row, size)
        new_col = posmod(new_col, size)
        return coords_to_index(new_row, new_col)
    else:
        if new_row < 0 or new_row >= size or new_col < 0 or new_col >= size:
            return -1
        return coords_to_index(new_row, new_col)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| size | int | 6–12 | Game Config | Grid dimension |
| index | int | 0 to size²-1 | caller | Cell to query |
| direction | enum | UP/DOWN/LEFT/RIGHT | caller | Direction to look |

### Adjacency Count

```
count_adjacent_owned(index, player_id):
    count = 0
    for direction in [UP, DOWN, LEFT, RIGHT]:
        neighbor = get_neighbor(index, direction)
        if neighbor != -1 and cells[neighbor].owner == player_id:
            count += 1
    return count
```

**Output range**: 0–4 (exactly 4 possible with wrap_around, 2–4 without depending on position).

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| All cells owned (no empty cells), `cursor_select_captured` = false | Match ends immediately — no cursor can spawn, no further actions possible | Default behavior; prevents stalemate since no castle clearing is possible without a cursor |
| All cells owned (no empty cells), `cursor_select_captured` = true | Cursor spawns on any cell (owned or empty) — game continues, players can destroy own castles or attack enemies | Optional rule enabling extended endgame play |
| All cells owned by one player | Match ends — dominant victory regardless of score | No further meaningful play possible |
| Contagion on empty cell | Preserved — if a player destroys their own castle, existing contagion from other players remains | Allows strategic re-capture; contagion represents "effort spent" |
| Contagion counter exceeds threshold | Should not happen — capture triggers at exactly threshold. If it does, treat as capture | Defensive coding; Rules Engine should prevent this |
| Wrap-around chain visits same cell twice | Chain stops when it returns to the starting cell. Cycle detection only activates when `wrap_around=true` AND `max_castles=0` (unlimited) AND `cursor_select_captured=true` — all other configurations terminate naturally via capture or empty cell | See Rules Engine for full cycle detection conditions |
| Grid size 6 with 8 players | Valid but crowded — 36 cells / 8 players = 4.5 cells per player average | Warned in UI per Game Config edge cases |
| `get_neighbor` on corner cell without wrap | Returns -1 for 2 of 4 directions | Expected behavior — callers must handle -1 |
| Cursor spawns on a cell that becomes owned between spawn decision and spawn execution | Should not happen — spawn is atomic. If it does, re-roll to a different empty cell | Turn Director owns cursor placement timing |
| Negative modulo for wrap-around (GDScript) | Use `posmod()` instead of `%` — GDScript `%` can return negative for negative operands | GDScript-specific: `posmod(-1, 8)` = 7, not -1 |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Game Config** | This depends on Game Config | Reads `grid_size`, `wrap_around` at board creation (hard). Note: `cursor_select_captured` is read by Turn Director for spawn targeting, not by Board State |
| **Rules Engine** | Rules Engine depends on this | Reads cell state, writes ownership/contagion changes (hard) |
| **Scoring System** | Scoring System depends on this | Reads `count_adjacent_owned()` for adjacency scoring (hard) |
| **Turn Director** | Turn Director depends on this | Reads empty cells for spawn targets, writes cursor state (hard) |
| **CPU Controller** | CPU Controller depends on this | Reads full board for AI decisions (hard) |
| **Board Renderer** | Board Renderer depends on this | Reads full board for visual display (hard) |

## Tuning Knobs

Board State itself has no tuning knobs — its shape is entirely determined by Game Config (`grid_size`, `wrap_around`). The data model is structural, not tunable.

Tuning that affects the board experience lives in:
- **Game Config**: `grid_size`, `wrap_around`
- **Turn Director**: cursor spawn timing and placement rules
- **Rules Engine**: capture/contagion thresholds

## Acceptance Criteria

- [ ] Board creates correct number of cells for all grid sizes 6–12 (36 to 144 cells)
- [ ] All cells start empty with no contagion
- [ ] `index_to_coords` and `coords_to_index` are inverse functions for all valid indices
- [ ] `get_neighbor` returns correct neighbor for all 4 directions on interior, edge, and corner cells
- [ ] `get_neighbor` with wrap_around=true always returns a valid index (never -1)
- [ ] `get_neighbor` with wrap_around=false returns -1 for off-edge directions
- [ ] `posmod()` used for wrap-around (not `%`) — verified with negative operands
- [ ] `count_adjacent_owned` returns 0–4 and matches manual count for test cases
- [ ] `get_cells_in_direction` with wrap_around stops when returning to start cell (cycle detection)
- [ ] `get_cells_in_direction` without wrap_around stops at board edge
- [ ] Contagion persists on cells after owner self-destructs
- [ ] Contagion resets for all players when a cell is captured via threshold
- [ ] Only Rules Engine and Turn Director can mutate board state
- [ ] No hardcoded grid size — all sizes derive from Game Config
- [ ] When all cells owned and `cursor_select_captured` = false, match ends immediately
- [ ] When all cells owned and `cursor_select_captured` = true, cursor can spawn on any cell
- [ ] Cursor respawn timer only starts after action chain completes, not on claim

## Post-V1: Board Shape Variants

Future consideration when obstacle/hazard cells are implemented:

- **Board shapes**: Diamond, hourglass/egg-timer, cross, ring — achieved by marking edge cells as blocked/inactive. Varies tactical exposure and access points.
- **Pre-placed positions**: Some cells start pre-owned or pre-blocked, creating asymmetric or themed maps.
- **Group adjacency scoring**: Alternative scoring mode that counts connected groups (flood-fill clusters) rather than only direct orthogonal neighbors. Rewards building contiguous territory over scattered captures.

These interact with the Game Config post-V1 options (`danger_cell_count`, `bonus_cell_count`, etc.).
