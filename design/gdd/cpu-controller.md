# CPU Controller

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-27
> **Implements Pillar**: Gameplay — provides AI opponents for solo and mixed play

## Overview

The CPU Controller provides AI opponents that participate in the cursor claim race alongside human players. Given a cursor position and the current board state, it decides whether to act, how quickly to respond, and which action to take (tap or directional swipe). Difficulty levels control reaction speed and decision quality. The CPU Controller submits actions to the Turn Director in exactly the same format as human players — the Turn Director does not know or care whether an action comes from a human or CPU.

## Player Fantasy

CPU opponents should feel like real competitors, not mechanical automatons. On Easy, they feel like a distracted friend — slow to react, making obviously suboptimal choices. On Medium, they're a competent player — reasonable speed, decent strategy. On Hard, they're the rival you love to beat — fast reactions, smart targeting, but not perfectly optimal (to avoid feeling unfair or robotic).

## Detailed Rules

### Core Rules

#### Decision Pipeline

When the Turn Director signals a cursor is ACTIVE:

1. **Reaction delay**: Wait a difficulty-based delay before evaluating (simulates human reaction time)
2. **Evaluate board**: Analyze cursor position relative to the board state
3. **Choose action**: Decide tap vs. swipe, and if swiping, which direction
4. **Submit**: Send `(player_id, action_type, direction?)` to Turn Director

If the cursor is claimed or expires before the CPU's reaction delay completes, the CPU does nothing.

#### Difficulty Profiles

| Parameter | Easy | Medium | Hard |
|-----------|------|--------|------|
| `reaction_min` | 1.5s | 0.6s | 0.2s |
| `reaction_max` | 3.0s | 1.5s | 0.6s |
| `strategic_bias` | 0.3 | 0.6 | 0.9 |
| `chain_awareness` | false | true | true |
| `threat_awareness` | false | false | true |

- **reaction_min/max**: Random delay range before acting (uniform distribution)
- **strategic_bias**: Probability of choosing the strategically optimal action vs. a random one (0.0 = always random, 1.0 = always optimal)
- **chain_awareness**: Whether the AI considers chain outcomes when choosing directions
- **threat_awareness**: Whether the AI considers enemy contagion threats on its own castles

#### Action Selection

The CPU evaluates each possible action (tap + 4 swipe directions = 5 options) and scores them:

##### Tap Scoring

Score the outcome of acting on the cursor cell only:
- Empty cell: score = adjacency bonus potential (count of own adjacent castles + 1)
- Enemy cell: score = current contagion level toward threshold (closer = more valuable)
- Own cell: score = -1 (destruction is rarely optimal, but valid when at max_castles)

##### Swipe Scoring (if chain_awareness = true)

For each direction, simulate the chain and sum the scores:
- Each empty capture in chain: +2
- Each contagion increment: +1, bonus +3 if it would reach threshold (capture)
- Each own castle destroyed: -2
- Chain length bonus: +1 per cell traversed (longer chains are generally better)

If `chain_awareness` = false, swipe directions are scored only by the first cell they hit (same as tap scoring, but the direction itself is random from the non-worst options).

##### Threat Awareness (Hard only)

If `threat_awareness` = true, adjust scores:
- Boost score for actions that target enemy castles with high contagion from the CPU (close to capture)
- Boost score for directions that chain through enemy territory the CPU is threatening
- Penalize actions that ignore cells where enemies have high contagion on CPU-owned castles (defensive awareness)

##### Final Selection

```
if randf() < strategic_bias:
    select highest-scoring action
else:
    select random action from all valid options (excluding self-destroy unless at max_castles)
```

#### Max Castles Handling

When the CPU is at or above `max_castles`:
- The CPU is action-locked (same as human players)
- Only valid action: destroy own castle (tap on own castle at cursor, or swipe through own castle)
- If cursor is not on an own castle and no swipe direction reaches one: CPU does nothing (waits for next cursor)

### States and Transitions

The CPU Controller is reactive — it activates only when signaled by the Turn Director:

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Waiting** | Match start / action submitted | Cursor becomes ACTIVE | Idle — no processing |
| **Reacting** | Cursor ACTIVE signal received | Reaction delay elapses | Timer running, no action yet |
| **Deciding** | Reaction delay complete | Action selected | Evaluate board, score options, pick action |
| **Submitting** | Decision made | Turn Director acknowledges | Submit action to Turn Director |

If cursor is claimed/expired during REACTING: return to WAITING immediately.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board State** | Reads | Full board for decision-making (ownership map, contagion levels, adjacency) |
| **Rules Engine** | Reads (simulation) | May simulate actions in read-only mode to evaluate chain outcomes (Medium/Hard) |
| **Game Config** | Reads | `cpu_difficulty` per player, `grid_size`, `wrap_around`, `max_castles`, `capture_threshold` |
| **Turn Director** | Submits to | Sends `(player_id, action_type, direction?)` — identical format to human input |

## Formulas

### Reaction Delay

```
reaction_delay = randf_range(difficulty.reaction_min, difficulty.reaction_max)
```

### Action Score (simplified)

```
score_action(action, cursor_index, board, config, difficulty):
    if action == TAP:
        return score_cell(cursor_index, cpu_player_id, board, config)
    else:  // SWIPE
        if difficulty.chain_awareness:
            return simulate_chain_score(cursor_index, action.direction, cpu_player_id, board, config)
        else:
            next = board.get_neighbor(cursor_index, action.direction)
            return score_cell(next if next != -1 else cursor_index, cpu_player_id, board, config)

score_cell(index, player_id, board, config):
    cell = board.cells[index]
    if cell.owner == null:
        adj = board.count_adjacent_owned(index, player_id)
        if adj == 0 and config.lone_castle_scores_zero:
            return 0  // isolated capture scores nothing — low priority
        return adj + 1
    elif cell.owner != player_id:
        contagion = cell.contagion.get(player_id, 0)
        near_capture = (contagion + 1 >= config.capture_threshold) ? 5 : 0
        return contagion + 1 + near_capture
    else:  // own castle
        return -1
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Cursor on CPU's own castle (not at max_castles) | Low score (-1) but valid; random selection might still pick it | Rarely optimal but not blocked |
| Cursor on CPU's own castle (at max_castles) | Only valid action — CPU immediately destroys | Required to unlock action restriction |
| All swipe directions go off-edge (corner, no wrap) | CPU chooses tap | No valid chain directions |
| CPU at max_castles, cursor not on own castle, no swipe reaches own castle | CPU does nothing — waits for next cursor | Cannot act without valid target |
| Two CPU players with same difficulty | Independent random delays — won't always act simultaneously | Random reaction times prevent lockstep behavior |
| Easy CPU on FRANTIC speed preset | CPU will almost never claim — reaction time (1.5-3.0s) exceeds cursor expire (2.0s) | Intentional — Easy CPU can't keep up with FRANTIC pace |
| Hard CPU vs. human on RELAXED preset | CPU claims most cursors — reaction time (0.2-0.6s) easily beats 8.0s expire | Intentional — Hard CPU dominates slow games |
| CPU simulates chain but board changes before it acts | CPU decision was based on pre-action board; if another player claimed first, CPU's analysis is discarded | CPU re-evaluates on next cursor |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Board State** | This depends on Board State | Reads full board for decision-making (hard) |
| **Rules Engine** | This depends on Rules Engine | Simulates chains in read-only mode (soft — Easy mode doesn't simulate) |
| **Game Config** | This depends on Game Config | Reads difficulty, grid params, constraints (hard) |
| **Turn Director** | Turn Director receives from this | Submits actions for claim racing (hard) |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `reaction_min` (Easy) | 1.5s | 0.5–5.0 | CPU reacts even slower — trivial opponent | Faster but still easy |
| `reaction_max` (Easy) | 3.0s | 1.0–8.0 | More variable, sometimes very slow | More consistent timing |
| `reaction_min` (Hard) | 0.2s | 0.05–0.5 | Less threatening | Near-instant reactions |
| `strategic_bias` | per difficulty | 0.0–1.0 | More optimal play | More random, less predictable |
| Chain/threat awareness | per difficulty | bool | Smarter chains | Simpler decisions |

These are defined in difficulty profile Godot Resources (`res://data/cpu_difficulty_easy.tres`, `_medium.tres`, `_hard.tres`), not in Game Config. Game Config's `cpu_difficulty` enum selects which resource to load. Adjusting profile values changes the feel of each difficulty tier. Profiles are data-driven — no code changes needed to tune difficulty.

## Acceptance Criteria

- [ ] Easy CPU: reaction time 1.5-3.0s, strategic_bias 0.3, no chain/threat awareness
- [ ] Medium CPU: reaction time 0.6-1.5s, strategic_bias 0.6, chain awareness enabled
- [ ] Hard CPU: reaction time 0.2-0.6s, strategic_bias 0.9, chain + threat awareness
- [ ] CPU submits actions in identical format to human players
- [ ] CPU does nothing if cursor claimed/expired before reaction delay completes
- [ ] CPU respects max_castles constraint — only self-destroys when at limit
- [ ] CPU at max_castles with no valid targets waits for next cursor
- [ ] Strategic action selection prefers higher-scoring actions by `strategic_bias` probability
- [ ] Random action selection (1 - strategic_bias) chooses uniformly from valid actions
- [ ] Chain simulation (Medium/Hard) correctly scores multi-cell outcomes
- [ ] Threat awareness (Hard) prioritizes near-capture enemy castles
- [ ] Multiple CPU players act independently with independent random delays
- [ ] CPU difficulty profiles are data-driven (not hardcoded in logic)
