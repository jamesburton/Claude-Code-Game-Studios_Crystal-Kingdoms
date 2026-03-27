# Match Flow

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-27
> **Implements Pillar**: Core loop — orchestrates the full match lifecycle

## Overview

Match Flow is the top-level orchestrator that manages a complete match from setup through play to conclusion. It initializes the board and players from Game Config, starts the Turn Director, accumulates scores from event logs, tracks per-player state (action counts, castle counts, bonus castle stacks), checks win/end conditions after every action, and produces the final match summary. It is the only system that knows "is the match still going?" and "who is winning?"

## Player Fantasy

Match Flow is felt at the macro level — the arc of a match. The opening scramble for territory, the mid-game tension of contagion wars, the endgame race to the winning score or time running out. The fantasy is a complete competitive experience with a clear beginning, rising tension, and a satisfying conclusion where the winner is earned, not arbitrary.

## Detailed Rules

### Core Rules

#### Match Lifecycle

```
SETUP → PLAYING → ENDING → COMPLETE
```

1. **SETUP**: Initialize match state from Game Config
   - Create Board State (empty grid of configured size)
   - Initialize per-player state: score = 0, actions = 0, castles_owned = 0, bonus_stack = []
   - Lock Game Config (read-only from this point)
   - Signal Turn Director to begin

2. **PLAYING**: The main gameplay phase
   - Turn Director runs the cursor spawn/claim/resolve cycle
   - Match Flow receives EventLogs after each action resolution
   - After each EventLog: update scores, update player state, check end conditions

3. **ENDING**: A match-end condition has been triggered
   - If triggered during chain resolution: wait for chain to complete (Turn Director handles this)
   - Freeze the Turn Director (no more cursor spawns)
   - Calculate final standings

4. **COMPLETE**: Match is over
   - Produce match summary (final scores, rankings, stats)
   - Signal UI to show results screen
   - Await user input to return to menu or rematch

#### Per-Player State

Match Flow owns and maintains these per-player fields during PLAYING:

| Field | Type | Updated By | Description |
|-------|------|------------|-------------|
| `score` | int | Match Flow (from EventLog points_delta) | Accumulated score |
| `actions_taken` | int | Match Flow (once per action, not per event) | Total actions this match |
| `castles_owned` | int | Match Flow (from EventLog captures/destroys) | Current castle count |
| `total_captures` | int | Match Flow (on capture_empty + capture_contagion) | Total castles captured this match |
| `max_castles_held` | int | Match Flow (high watermark after each action) | Peak simultaneous castle ownership |
| `longest_chain` | int | Match Flow (from EventLog chain length) | Longest chain executed this match |
| `bonus_stack` | int[] | Match Flow (from Rules Engine constraint logic) | FILO stack of excess castle indices when over max_castles |

#### Score Accumulation

After receiving an EventLog from the Turn Director:

```
// Increment action count ONCE per action (not per event in the chain)
actor.actions_taken += 1

for event in event_log:
    match event.type:
        capture_empty:
            actor.score += event.points_delta
            actor.castles_owned += 1
            actor.total_captures += 1
        increment_contagion:
            actor.score += event.points_delta
        capture_contagion:
            actor.score += event.points_delta
            actor.castles_owned += 1
            actor.total_captures += 1
            target_player.score += event.target_points_lost  // negative
            target_player.castles_owned -= 1
            // Update bonus stacks for both players
            update_bonus_stack(actor, event.grid_index)
            update_bonus_stack_on_loss(target_player, event.grid_index)
        destroy_own_castle:
            actor.castles_owned -= 1
            // Remove from bonus stack if applicable
            remove_from_bonus_stack(actor, event.grid_index)
        chain_ended:
            // Informational only — no score changes

// Update high watermarks after processing all events
actor.max_castles_held = max(actor.max_castles_held, actor.castles_owned)
actor.longest_chain = max(actor.longest_chain, len(event_log) - 1)  // exclude chain_ended event
```

#### Match End Conditions

Checked after each action resolution (full EventLog processed):

| Condition | Trigger | Priority |
|-----------|---------|----------|
| **Time limit** | Match elapsed time ≥ `config.time_limit` (if > 0) | Checked continuously by timer |
| **Winning score** | Any player's score ≥ `config.winning_score` (if > 0) | Checked after each EventLog |
| **No valid targets** | No empty cells and `cursor_select_captured` = false | Checked before each cursor spawn |
| **Dominant victory** | One player owns all cells | Checked after each EventLog |

**Priority**: If multiple conditions trigger simultaneously (e.g., winning score reached AND time expires), the winning score takes precedence for determining the winner.

**Tie-breaking** (when time runs out with tied scores):
1. Most castles currently owned
2. Most total captures during the match
3. Fewest actions taken (more efficient player wins)
4. If still tied: draw

#### Match Summary

Produced at COMPLETE:

```
MatchSummary:
    winner: PlayerId | null  // null if draw
    rankings: PlayerRanking[]  // sorted by final score descending
    duration: float  // actual match time in seconds
    end_reason: TIME_LIMIT | WINNING_SCORE | NO_TARGETS | DOMINANT_VICTORY

PlayerRanking:
    player_id: PlayerId
    final_score: int
    castles_at_end: int
    total_captures: int
    total_actions: int
    max_castles_held: int  // high watermark
    longest_chain: int
```

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **SETUP** | User starts match from menu | Board created, players initialized | Initialize all state, lock config |
| **PLAYING** | Setup complete | End condition triggered | Turn Director active, scores accumulating |
| **ENDING** | End condition triggered | Current chain completes (if any) | Turn Director freezing, final scores calculated |
| **COMPLETE** | All resolution finished | User chooses rematch or exit | Show summary, await user input |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Game Config** | Reads | All match params at SETUP; reads constraints during PLAYING |
| **Board State** | Reads | Cell ownership for dominant victory check, target availability |
| **Turn Director** | Orchestrates | Starts/stops the Turn Director; receives EventLogs and turn-cycle events |
| **Rules Engine** | Indirect (via Turn Director) | EventLogs flow through Turn Director to Match Flow |
| **Scoring System** | Reads | Win condition checking (winning_score comparison) |
| **Board Renderer** | Signals | Match state changes (start, end, pause) for visual transitions |
| **HUD / Score Panel** | HUD reads from this | Current scores, timer, player state for display |
| **Scene Management** | Signals | Match complete → transition to results/menu scene |

## Formulas

### Match Timer

```
elapsed = current_time - match_start_time
remaining = max(0, config.time_limit - elapsed)
is_time_up = config.time_limit > 0 and elapsed >= config.time_limit
```

### Tie-Breaking

```
rank_players(players):
    sort by:
        1. score (descending)
        2. castles_owned (descending)
        3. total_captures (descending)
        4. actions_taken (ascending — fewer is better)
    // If all 4 criteria match: draw between those players
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| `time_limit` = 0 and `winning_score` = 0 | Blocked by Game Config validation — at least one end condition required | Prevents infinite matches |
| Winning score reached by two players in the same chain | Player whose capture event came first in the EventLog wins | Events are ordered; first to reach threshold wins |
| All players have score 0 at time limit | Draw — no tiebreaker can resolve | Valid outcome |
| Player disconnects (gamepad) mid-match | Match pauses, awaiting reconnect or removal | Handled by Input System pause; Match Flow stays in PLAYING |
| Rematch requested | Reset all per-player state, keep Game Config, restart from SETUP | Quick restart without returning to menu |
| Match lasts exactly `time_limit` seconds | Time is up — same as exceeding the limit | >= comparison, not > |
| Score goes negative (many castle losses) | Allowed — score can be negative | No floor on player score |
| Bonus castle stack manipulation during rapid chain events | Stack updates are synchronous within EventLog processing — no race conditions | EventLog is processed sequentially |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Game Config** | This depends on Game Config | Reads match params, constraints, end conditions (hard) |
| **Board State** | This depends on Board State | Reads cell state for victory checks (hard) |
| **Turn Director** | This orchestrates Turn Director | Starts/stops turn cycle, receives events (hard) |
| **Rules Engine** | Indirect dependency | EventLogs produced by Rules Engine flow through Turn Director (hard) |
| **Scoring System** | Indirect only | Match Flow reads pre-computed `points_delta` from EventLogs, does not call Scoring System directly. Win condition is a simple `score >= winning_score` comparison |
| **HUD / Score Panel** | HUD depends on this | Reads scores, timer, player state for display (hard) |
| **Board Renderer** | Renderer depends on this | Match lifecycle signals (soft) |
| **Scene Management** | Scene Management depends on this | Match complete triggers scene transition (soft) |

## Tuning Knobs

Match Flow has no independent tuning knobs. All match parameters come from Game Config:
- `time_limit`, `winning_score` (end conditions)
- `max_actions`, `max_castles` (constraints)
- All scoring parameters (affect score accumulation rate)

The "feel" of match pacing is controlled by Turn Director timing (Game Config speed presets).

## Acceptance Criteria

- [ ] Match lifecycle follows SETUP → PLAYING → ENDING → COMPLETE
- [ ] Board State initialized correctly from Game Config at SETUP
- [ ] Per-player state (score, actions, castles, bonus stack) initialized to zero/empty
- [ ] Game Config locked at match start — no modifications during play
- [ ] Scores accumulate correctly from EventLog points_delta
- [ ] Castle counts update on capture_empty, capture_contagion, destroy_own_castle
- [ ] Points lost applied to correct player (the captured player, not the actor)
- [ ] Bonus castle FILO stack maintained correctly through all event types
- [ ] Time limit ends match when elapsed >= time_limit
- [ ] Winning score ends match when any player's score >= winning_score
- [ ] No valid targets (all owned, cursor_select_captured=false) ends match
- [ ] Dominant victory (one player owns all) ends match
- [ ] Chain in progress at match-end completes before match concludes
- [ ] Tie-breaking resolves correctly through all 4 criteria
- [ ] Match summary produced with correct rankings and statistics
- [ ] Rematch resets state while preserving Game Config
- [ ] Negative scores allowed (no floor clamp on player score)
- [ ] actions_taken increments once per action, not once per event in a chain
