# Turn Director

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-27
> **Implements Pillar**: Core loop — the heartbeat that drives gameplay

## Overview

The Turn Director is the real-time orchestrator of Crystal Kingdoms' core loop. It manages the cycle of cursor spawning, player claim racing, action resolution, and cooldown. It decides WHEN things happen (timing), WHO gets to act (claim racing), and delegates WHAT happens to the Rules Engine. It is the bridge between the Input System (player intent) and the Rules Engine (game logic). The Turn Director owns the pace and rhythm of the game.

## Player Fantasy

The Turn Director creates the tension and excitement that defines Crystal Kingdoms. The anticipation of "where will the cursor appear?", the adrenaline of racing to claim it, the brief moment of decision before acting — this is the heartbeat of the game. The fantasy is a constant cycle of tension and release: wait, react, decide, watch the result, repeat.

## Detailed Rules

### Core Rules

#### The Turn Cycle

Each "turn" follows this sequence:

```
IDLE → SPAWNING → ACTIVE → CLAIMED → RESOLVING → COOLDOWN → IDLE
```

1. **IDLE**: No cursor on board. Waiting to spawn the next cursor.
2. **SPAWNING**: Spawn delay timer running (random between `cursor_spawn_delay_min` and `cursor_spawn_delay_max`). No cursor visible yet.
3. **ACTIVE**: Cursor placed on a cell, visible and claimable. All players race to act. Expire timer running.
4. **CLAIMED**: A player has claimed the cursor (first valid input received). The cursor disappears. The player's action (tap or swipe) is determined.
5. **RESOLVING**: The action is passed to the Rules Engine. Event log is produced. Board state is being mutated. Chain traversal may be in progress.
6. **COOLDOWN**: Action complete. Cursor respawn delay timer starts. This is the gap between seeing results and the next cursor.

Note: COOLDOWN and SPAWNING could be merged — the respawn delay IS the spawn delay for the next cursor. The distinction is conceptual: COOLDOWN is "results are settling", SPAWNING is "next cursor is coming."

#### Cursor Spawn Target Selection

When spawning a cursor:

1. Collect all valid target cells:
   - If `cursor_select_captured` = false: all cells where `owner == null` (empty cells only)
   - If `cursor_select_captured` = true: all cells (any ownership state)
2. If no valid targets exist:
   - If `cursor_select_captured` = false: match ends immediately (no further play possible)
   - If `cursor_select_captured` = true: should not happen (all cells are valid)
3. Select one cell at random (uniform distribution)
4. Place cursor: set `board.cursor_index`, `board.cursor_active = true`

#### Claim Racing

While the cursor is ACTIVE:

1. Listen for input actions from all human players (via Input System) and CPU players (via CPU Controller)
2. The **first valid action** received claims the cursor:
   - Set `board.cursor_active = false` (cursor disappears)
   - Record the claiming player and their action type
   - Transition to CLAIMED → RESOLVING
3. If `cursor_expire_time` elapses with no claim:
   - Cursor expires — remove from board (`cursor_index = -1`, `cursor_active = false`)
   - Transition to COOLDOWN (respawn timer starts)

**Validity pre-check** (lightweight, not authoritative): The Turn Director performs a quick pre-check before accepting a claim:
- Is the player action-locked? (at `max_actions` limit, or at `max_castles` and cursor is not on their own castle)
- If pre-check rejects: the claim is ignored, cursor stays ACTIVE for other players

The **Rules Engine is the authoritative enforcer** of all constraints. If a pre-check passes but the Rules Engine rejects the action (edge case), the action produces an empty EventLog and the cursor is consumed — a new spawn cycle begins. This should not happen in practice since the pre-check mirrors the Rules Engine's constraints, but the Rules Engine is the single source of truth.

#### Action Hand-off

Once claimed:

1. Pass `(actor_id, action_type, direction?)` to Rules Engine
2. Rules Engine resolves the action, mutates Board State, returns EventLog
3. Turn Director emits the EventLog to observers (Match Flow, Board Renderer, etc.)
4. When resolution is complete, emit EventLog to Board Renderer for animation
5. Wait for Board Renderer's `animation_complete` signal before transitioning to COOLDOWN
6. Respawn delay timer starts — only AFTER animation is fully complete

#### CPU Controller Integration

The Turn Director does not call the CPU Controller directly. Instead:

1. When cursor becomes ACTIVE, Turn Director signals all players (including CPU)
2. CPU Controller receives the signal with cursor position and board state
3. CPU Controller calculates its response with a difficulty-based delay
4. CPU Controller submits its action to the Turn Director like any other player
5. Turn Director treats CPU actions identically to human actions for claim racing

### States and Transitions

| State | Entry Condition | Exit Condition | Duration |
|-------|----------------|----------------|----------|
| **IDLE** | Match start / previous COOLDOWN complete | Spawn timer starts | Instantaneous (immediately begins SPAWNING) |
| **SPAWNING** | IDLE transitions | Spawn delay elapses | `cursor_spawn_delay_min` to `cursor_spawn_delay_max` (random) |
| **ACTIVE** | Spawn delay complete, cursor placed | Player claims cursor OR expire timer elapses | Up to `cursor_expire_time` |
| **CLAIMED** | First valid action received | Action passed to Rules Engine | Instantaneous |
| **RESOLVING** | Rules Engine processing | EventLog returned, chain complete | Variable (depends on chain length × `chain_step_delay`) |
| **COOLDOWN** | Resolution complete | Respawn delay elapses | Transitions immediately to SPAWNING |

**Match-end interrupts**: If the match ends (time limit, winning score) during any state:
- SPAWNING/ACTIVE/CLAIMED: Cancel immediately, match ends
- RESOLVING: Complete the current chain, then match ends (per resolved rules)
- The Turn Director checks match-end conditions after each resolution

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board State** | Reads + writes | Reads empty cells for spawn targets; writes `cursor_index`, `cursor_active` |
| **Rules Engine** | Calls | Passes `(actor_id, action_type, direction?)` → receives EventLog |
| **Input System** | Reads | Receives human player actions `(player_id, action_type)` |
| **CPU Controller** | Receives from | CPU submits actions in the same format as human players |
| **Game Config** | Reads | `cursor_spawn_delay_min/max`, `cursor_expire_time`, `cursor_select_captured` for spawn targeting; `max_actions`, `max_castles` for pre-check only (Rules Engine is authoritative) |
| **Match Flow** | Signals | Emits EventLog and turn-cycle events (cursor_spawned, cursor_claimed, cursor_expired, action_resolved) |

## Formulas

### Spawn Delay Calculation

```
spawn_delay = randf_range(config.cursor_spawn_delay_min, config.cursor_spawn_delay_max)
```

| Variable | Type | Range | Source |
|----------|------|-------|--------|
| cursor_spawn_delay_min | float | 0.5–5.0 | Game Config |
| cursor_spawn_delay_max | float | 1.0–10.0 | Game Config |

### Resolution Duration (for chain actions)

```
resolution_time = chain_length * config.chain_step_delay
```

Where `chain_length` is the number of cells traversed (determined by Rules Engine during resolution). For tap actions, `chain_length = 1`.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Cursor spawns, no one claims it | Cursor expires after `cursor_expire_time`, new spawn cycle begins | Normal gameplay — not every cursor is contested |
| Two players input on the exact same frame | First processed by timestamp order wins. If truly simultaneous (identical timestamps due to timer resolution), resolve by fair random selection (not player_id order) to avoid positional advantage | Fairness over determinism — no player should benefit from their ID |
| Player claims cursor but is at max_castles and cursor is on enemy cell | Action rejected by validity check — cursor remains ACTIVE for others | Pre-claim validation prevents wasted claims |
| Match time runs out during SPAWNING | Cancel spawn, match ends immediately | No action was in progress |
| Match time runs out during RESOLVING | Chain completes, then match ends | Per resolved game rules — in-progress chains finish |
| Winning score reached during chain resolution | Chain completes, then match ends with winner | Same as time limit — finish the current action |
| All cells owned, cursor_select_captured = false | No valid spawn targets → match ends | Covered in Board State edge cases |
| Cursor spawn delay of 0.5s (minimum) on FRANTIC preset | Valid — creates intense pace with almost no gap between turns | Player chose this experience |
| CPU and human both submit at the same time | Same tiebreak rule as two humans — first by timestamp, fair random if identical | Fair regardless of player type |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Board State** | This depends on Board State | Reads cells for spawn targets, writes cursor state (hard) |
| **Rules Engine** | This depends on Rules Engine | Delegates action resolution (hard) |
| **Input System** | This depends on Input System | Receives human player actions (hard) |
| **Game Config** | This depends on Game Config | Reads timing params, cursor_select_captured, constraints (hard) |
| **CPU Controller** | CPU Controller feeds into this | CPU submits actions (soft — game works without CPU players) |
| **Match Flow** | Match Flow depends on this | Receives turn-cycle events and EventLogs (hard) |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `cursor_spawn_delay_min` | 1.0s | 0.5–5.0 | More breathing room between turns | Relentless pace |
| `cursor_spawn_delay_max` | 3.0s | 1.0–10.0 | More unpredictable spawn timing | More regular rhythm |
| `cursor_expire_time` | 5.0s | 2.0–15.0 | More time to decide | Forces faster reactions |
| `chain_step_delay` | 0.2s | 0.05–1.0 | Chain traversal visible step-by-step | Chain resolves near-instantly |

All tuning knobs are owned by Game Config — the Turn Director reads them. Adjusting these fundamentally changes the game's pace and feel (see Speed Presets in Game Config).

## Acceptance Criteria

- [ ] Turn cycle follows IDLE → SPAWNING → ACTIVE → CLAIMED → RESOLVING → COOLDOWN sequence
- [ ] Cursor spawns on a random valid cell after spawn delay elapses
- [ ] Cursor only spawns on empty cells when `cursor_select_captured` = false
- [ ] Cursor can spawn on any cell when `cursor_select_captured` = true
- [ ] Match ends when no valid spawn targets and `cursor_select_captured` = false
- [ ] First valid player action claims the cursor — all subsequent actions rejected
- [ ] Cursor disappears immediately on claim
- [ ] Respawn timer starts only AFTER action chain fully completes (not on claim)
- [ ] Unclaimed cursor expires after `cursor_expire_time`
- [ ] Expired cursor triggers new spawn cycle (not match end)
- [ ] Action validity checked before claim: max_actions, max_castles constraints respected
- [ ] CPU actions processed identically to human actions for fairness
- [ ] Simultaneous inputs resolved by timestamp order; identical timestamps use fair random selection (no player_id bias)
- [ ] Match-end during RESOLVING: chain completes before match ends
- [ ] Match-end during SPAWNING/ACTIVE: cancels immediately
- [ ] EventLog emitted to observers after each action resolution
- [ ] No state changes between cursor spawn and cursor claim (board is stable while cursor is active)
