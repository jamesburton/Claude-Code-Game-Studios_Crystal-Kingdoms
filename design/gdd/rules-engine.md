# Rules Engine

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-27
> **Implements Pillar**: Foundation — deterministic game logic all systems depend on

## Overview

The Rules Engine is the deterministic core of Crystal Kingdoms. Given a player action (tap or directional swipe) and the current board state, it resolves the action step-by-step: capturing empty castles, incrementing contagion on enemy castles, destroying own castles, and traversing chains. It produces a deterministic event log alongside state changes, enabling predictable testing, replay, animation sequencing, and separation of game logic from presentation. The Rules Engine never initiates actions — it only resolves them when called by the Turn Director.

## Player Fantasy

The Rules Engine is invisible to players, but they feel it in every action: the satisfying snap of capturing an empty castle, the rising tension of contagion ticks building toward a takeover, the dramatic sweep of a chain carving across the board. The fantasy is that the game rules are always fair, always predictable, and always produce interesting consequences — every action matters and creates a ripple effect.

## Detailed Rules

### Core Rules

#### Action Types

The Rules Engine accepts two action types:

1. **Tap** (fire): Resolve action on the cursor cell only
2. **Swipe** (directional): Resolve action on the cursor cell, then chain in the given direction

#### Single-Cell Resolution

When an action targets a cell, the outcome depends on the cell's current state relative to the actor:

| Cell State | Action | Result | Event Type |
|------------|--------|--------|------------|
| Empty (no owner) | Any | Actor captures the castle | `capture_empty` |
| Owned by enemy | Any | Increment actor's contagion on this cell | `increment_contagion` |
| Owned by enemy, contagion reaches threshold | Any | Actor captures the castle, all contagion on this cell resets | `capture_contagion` |
| Owned by actor | Any | Castle destroyed (ownership cleared, contagion preserved) | `destroy_own_castle` |

#### Chain Resolution

When a direction is provided (swipe action):

1. Start at the cursor cell — resolve it using single-cell rules
2. Determine if the chain continues:
   - **Chain continues** after: `increment_contagion` (hitting enemy, not capturing)
   - **Chain stops** after: `capture_empty`, `capture_contagion`, `destroy_own_castle`
3. If continuing, move to the next cell in the direction (using Board State `get_neighbor`)
4. If next cell is -1 (off edge, no wrap): chain ends → emit `chain_ended`
5. If next cell is the starting cell (wrap cycle): chain ends → emit `chain_ended`
6. Repeat from step 2 with the new cell

**Chain continuation rule**: A chain only continues through enemy castles that are NOT captured (contagion incremented but threshold not reached). Any other outcome stops the chain. This makes chains most powerful when sweeping through heavily defended enemy territory.

#### Event Log

Every action produces an ordered array of events. Each event contains:

```
Event:
    type: EventType
    grid_index: int          # which cell was affected
    actor_id: PlayerId       # who performed the action
    points_delta: int        # score change for the actor (can be 0 or negative)
    target_owner: PlayerId?  # previous owner (for captures/contagion), null for empty
    target_points_lost: int  # points deducted from target_owner (0 unless capture_contagion)
    contagion_level: int?    # new contagion level (for increment_contagion)
    chain_position: int      # 0-indexed position in the chain (0 = first cell)
```

`target_points_lost` is always 0 except for `capture_contagion` events, where it holds the negative point value applied to the captured player (calculated using the captured player's adjacent count and the `points_lost_base` scorer).

**EventType** enum: `capture_empty`, `increment_contagion`, `capture_contagion`, `destroy_own_castle`, `chain_ended`

The event log is the **sole interface** between the Rules Engine and the presentation layer. The Renderer/VFX/Audio systems consume events to drive animations and sound — they never read the resolution logic directly.

#### Scoring Integration

The Rules Engine calculates `points_delta` for each event by reading the scoring configuration from Game Config:

| Event | Score Calculation |
|-------|-----------------|
| `capture_empty` | `effective(count_adjacent_owned(cell, actor), adjacency_curve, adjacency_multiplier, adjacency_adjustment)` |
| `increment_contagion` | `effective(new_contagion_level, contagion_curve, contagion_multiplier, contagion_adjustment)` — 0 in ONLY_CASTLES mode |
| `capture_contagion` | `effective(min(actor_castle_count, capture_cap), capture_curve, capture_multiplier, capture_adjustment)` where capture_cap = capture_threshold when threshold < 4, else uncapped |
| `destroy_own_castle` | 0 (no points for self-destruction) |
| `chain_ended` | 0 (informational event only) |

Points lost for the **previous owner** of a captured castle (via `capture_contagion`):
- Calculated using `points_lost_base` scorer with the **captured player's** adjacent count at the lost cell (counted BEFORE the castle changes hands)
- Stored in the `target_points_lost` field of the `capture_contagion` event (always negative)
- `actor_castle_count` for capture scoring is the post-capture count (including the newly captured castle)

#### Constraint Checking

Before resolving an action, the Rules Engine checks constraints from Game Config:

**max_actions**: If the actor has reached their action limit, reject the action (no resolution).

**max_castles** (when limit > 0 and player is at or above limit):

1. **Action restriction**: The player may ONLY act on their own castles (to destroy them). Any action targeting an empty or enemy castle is rejected.
2. **Chain exception**: If a chain is already in progress and a contagion capture pushes the player over the limit mid-chain, the capture is allowed and the chain continues normally. The player may end the chain with more castles than the limit.
3. **Excess castles ("bonus castles")**: Castles captured beyond the limit are tracked on a FILO stack (last in, first out). These castles are visually marked with a star/twinkle indicator to show they are excess.
4. **Returning to limit**: The bonus stack shrinks in two ways:
   - **Direct removal**: If a bonus castle is destroyed (by enemy capture or any means), it is removed from the stack directly.
   - **Indirect removal**: If a non-bonus castle is lost (enemy captures it), the player's total count drops. The most recent castle on the bonus stack is reclassified as a regular castle (popped from the stack), since the player is now closer to the limit.
5. **Action lock persists** until the player's castle count is at or below `max_castles` AND the bonus stack is empty. While locked, the player can still claim cursors but can only destroy their own castles.

**Example flow** (max_castles = 5):
- Player has 5 castles → at limit, can only self-destroy
- Player self-destroys → 4 castles, can act normally
- Player does a chain that captures 3 castles → 7 castles, bonus stack = [castle_a, castle_b, castle_c]
- Enemy captures castle_b (a bonus castle) → removed from stack, 6 castles, bonus stack = [castle_a, castle_c]
- Enemy captures a non-bonus castle → 5 castles, castle_c popped from bonus stack → bonus stack = [castle_a]
- Player still locked (bonus stack not empty, count = 5 = limit)
- Player self-destroys → 4 castles, castle_a popped → bonus stack empty, normal play resumes

### States and Transitions

The Rules Engine is stateless — it is a pure function. Given (BoardState, GameConfig, Action) → (BoardState', EventLog). It holds no internal state between calls.

The bonus castle stack is stored per-player in the match state (owned by Match Flow), not in the Rules Engine itself. The Rules Engine reads and updates it during resolution.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board State** | Reads + writes | Reads cell ownership/contagion; writes captures, contagion increments, resets, destroys |
| **Game Config** | Reads | All scoring params (curves, multipliers, adjustments), `capture_threshold`, `wrap_around`, `max_actions`, `max_castles`, `scoring_mode` |
| **Scoring System** | Rules Engine calls | Delegates effective score calculation to Scoring System's curve evaluator |
| **Turn Director** | Called by Turn Director | Turn Director passes (actor_id, action_type, direction?) → receives EventLog |
| **CPU Controller** | CPU Controller simulates | CPU may call Rules Engine in read-only/simulation mode to evaluate potential moves |
| **Match Flow** | Match Flow reads events | Consumes EventLog to update scores, check win conditions; owns the per-player bonus castle stacks |
| **Board Renderer** | Renderer reads events | Consumes EventLog to drive animations and visual feedback |

## Formulas

The Rules Engine delegates scoring curve evaluation to the Scoring System (see [Game Config formulas](game-config.md#formulas)). The Rules Engine's own formulas are the resolution logic:

### Contagion Resolution

```
resolve_contagion(cell, actor_id, config):
    current = cell.contagion.get(actor_id, 0)
    new_level = current + 1
    if new_level >= config.capture_threshold:
        // Capture — reset all contagion, change owner
        cell.owner = actor_id
        cell.contagion = {}
        return (capture_contagion, new_level)
    else:
        cell.contagion[actor_id] = new_level
        return (increment_contagion, new_level)
```

### Chain Traversal

```
resolve_chain(start_index, direction, actor_id, board, config):
    events = []
    current = start_index
    position = 0

    // Cycle detection required only when wrap_around is true
    // AND max_castles is unlimited (0) AND cursor_select_captured is true
    // (otherwise chain is guaranteed to terminate via capture or empty cell)
    needs_cycle_check = board.wrap_around
        and config.max_castles == 0
        and config.cursor_select_captured
    visited = {start_index} if needs_cycle_check else null

    loop:
        event = resolve_cell(current, actor_id, board, config, position)
        events.append(event)

        if event.type != increment_contagion:
            break  // chain stops

        next = board.get_neighbor(current, direction)
        if next == -1:
            events.append(chain_ended_event(current, position))
            break

        if needs_cycle_check and next in visited:
            events.append(chain_ended_event(current, position))
            break

        if needs_cycle_check:
            visited.add(next)
        current = next
        position += 1

    return events
```

### Points Lost Calculation

```
calc_points_lost(cell_index, captured_player_id, board, config):
    adj_count = board.count_adjacent_owned(cell_index, captured_player_id)
    // Note: count BEFORE the castle is lost (includes neighbors still owned)
    base = scoring_system.effective(adj_count, config.points_lost_base_curve...)
    return -max(1, round_half_up(base * config.points_lost_multiplier + config.points_lost_adjustment))
```

Note: The adjacent count is calculated **before** the castle changes hands, reflecting the strategic value of the position the player is losing.

### Lone Castle Scoring (n=0 adjacency)

```
score_empty_capture(cell_index, actor_id, board, config):
    adj_count = board.count_adjacent_owned(cell_index, actor_id)
    if adj_count == 0:
        if config.lone_castle_scores_zero:
            return 0
        else:
            return 1  // minimum 1 point
    else:
        return effective(adj_count, config.adjacency_curve, config.adjacency_multiplier, config.adjacency_adjustment)
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Chain wraps around entire board | Allowed in most configs — chain terminates naturally when it hits an empty cell, captures via contagion, or hits actor's own castle. Cycle detection only needed when `wrap_around=true` AND `max_castles=0` (unlimited) AND `cursor_select_captured=true` | Only that specific combination can produce an all-enemy board with no natural chain termination |
| Chain hits board edge (no wrap) | Chain ends, `chain_ended` event emitted | Clean termination |
| Actor taps own castle at cursor | Castle destroyed, `destroy_own_castle` event | Valid action — self-destruction is always allowed |
| Actor at max_castles taps enemy castle | Action rejected — player is locked to self-destroy only | Constraint enforcement |
| Actor at max_castles taps own castle | Allowed — self-destroy reduces count | Only permitted action when at limit |
| Chain captures multiple castles mid-chain | Each capture resolved independently in chain order; bonus stack grows with each | Chain exception allows exceeding limit mid-chain |
| Chain hits actor's own castle mid-chain | Castle destroyed, chain stops | `destroy_own_castle` is a chain-stopping event |
| Capture via contagion where captured player has 0 adjacent castles | Points lost uses n=0 → effective = max(1, ...) = minimum 1 point lost | Floor clamp ensures losing a castle always costs something |
| Multiple players have contagion on a cell; one captures it | All contagion from all players is reset on capture | Clean slate — the winner takes all |
| Empty capture with 0 adjacent owned castles | If `lone_castle_scores_zero` = true → 0 points. If false → 1 point (minimum) | Configurable — lone placements can be valueless to encourage territory-building |
| `max_actions` reached mid-chain | Chain completes (action was already started), but player cannot start new actions | Constraint checked at action start, not during chain |
| Bonus castle destroyed by enemy while player is over limit | Removed from bonus stack directly; if count drops to limit and stack is empty, lock lifts | Stack consistency maintained |
| Two chains resolve simultaneously | Impossible — Turn Director ensures one action at a time | Architecture prevents this |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Board State** | This depends on Board State | Reads cell ownership/contagion; writes captures, increments, resets, destroys (hard) |
| **Game Config** | This depends on Game Config | Reads scoring params, `capture_threshold`, `wrap_around`, `max_actions`, `max_castles`, `scoring_mode`, `cursor_select_captured`, `lone_castle_scores_zero` (hard) |
| **Scoring System** | This depends on Scoring System | Delegates curve evaluation for point calculations (hard) |
| **Turn Director** | Turn Director depends on this | Calls Rules Engine to resolve actions (hard) |
| **CPU Controller** | CPU Controller depends on this | Simulates actions in read-only mode for AI evaluation (soft) |
| **Match Flow** | Match Flow depends on this | Consumes event logs for score updates, win condition checks; owns bonus castle stacks (hard) |
| **Board Renderer** | Board Renderer depends on this | Consumes event logs for animation sequencing (hard) |

## Tuning Knobs

The Rules Engine has no tuning knobs of its own — it is pure deterministic logic. All tunable values live in Game Config and are passed through:

- **Capture difficulty**: `capture_threshold` (Game Config)
- **Scoring feel**: curve selectors, multipliers, adjustments (Game Config)
- **Action economy**: `max_actions`, `max_castles` (Game Config)
- **Board topology**: `wrap_around`, `cursor_select_captured` (Game Config)
- **Lone capture value**: `lone_castle_scores_zero` (Game Config)

The Rules Engine's behavior changes entirely based on these inputs, but it has no independent parameters to tune.

## Acceptance Criteria

- [ ] Tap action resolves on cursor cell only — no chain traversal
- [ ] Swipe action resolves cursor cell then chains in the given direction
- [ ] Empty castle capture assigns ownership to actor
- [ ] Enemy castle increments actor's contagion counter on that cell
- [ ] Contagion reaching threshold captures castle and resets ALL players' contagion on that cell
- [ ] Acting on own castle destroys it (clears ownership, preserves contagion)
- [ ] Chain continues only after `increment_contagion` — stops on all other events
- [ ] Chain stops at board edge when wrap_around is false
- [ ] Chain cycle detection activates only when wrap_around=true AND max_castles=0 AND cursor_select_captured=true
- [ ] Event log is produced for every action, ordered by chain position
- [ ] Each event contains correct `type`, `grid_index`, `actor_id`, `points_delta`, `chain_position`
- [ ] Points lost for captured player uses the captured player's adjacent count (not captor's)
- [ ] Points lost adjacent count is calculated BEFORE ownership changes
- [ ] Capture score cap applies: n clamped to `capture_threshold` when threshold < 4
- [ ] `lone_castle_scores_zero` = true → empty capture with 0 adjacent scores 0
- [ ] `lone_castle_scores_zero` = false → empty capture with 0 adjacent scores 1
- [ ] ONLY_CASTLES mode: contagion events produce 0 points
- [ ] `max_actions` check rejects action at limit; mid-chain actions complete
- [ ] `max_castles` lock: player can only self-destroy when at or above limit
- [ ] Chain exception: mid-chain captures allowed even when over max_castles
- [ ] Bonus castle FILO stack tracks excess castles correctly
- [ ] Bonus castle direct removal works when bonus castle is destroyed
- [ ] Bonus castle indirect removal: losing a non-bonus castle pops top of stack
- [ ] Rules Engine is deterministic: same inputs always produce same outputs
- [ ] No hardcoded values — all thresholds, scoring, and constraints from Game Config
