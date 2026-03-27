# HUD / Score Panel

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-27
> **Implements Pillar**: Presentation — real-time game information display

## Overview

The HUD / Score Panel displays all real-time match information to players: scores, match timer, player rankings, action counts, castle counts, and active event feedback (point popups, chain announcements). It reads from Match Flow's per-player state and renders as a Godot Control node layer above the board. It also shows the end-of-match summary screen with final standings, statistics, and rematch/exit options.

## Player Fantasy

The HUD is the scoreboard that fuels competition. Seeing your name climb the rankings, watching your score tick up with each capture, glancing at the timer counting down — these create urgency and rivalry. The fantasy is a clear, glanceable dashboard where you always know where you stand: "I'm winning by 12 points with 30 seconds left" or "I'm behind but I have more castles — one good chain could turn it around."

## Detailed Rules

### Core Rules

#### HUD Layout

The HUD occupies the edges of the viewport, leaving the center for the board:

```
┌──────────────────────────────────────┐
│  TIMER        MATCH INFO        MODE │  ← Top bar
├──────────────────────────────────────┤
│         │                    │       │
│  P1     │                    │  P5   │
│  P2     │     GAME BOARD     │  P6   │  ← Side panels (for 5-8 players)
│  P3     │                    │  P7   │
│  P4     │                    │  P8   │
│         │                    │       │
├──────────────────────────────────────┤
│  POINT POPUPS / EVENT FEED          │  ← Bottom bar (optional)
└──────────────────────────────────────┘
```

For 2-4 players, only the left panel is used. For 5-8, both side panels.

#### Top Bar

| Element | Content | Update Frequency |
|---------|---------|-----------------|
| Timer | `MM:SS` countdown (or count-up if no time limit) | Every second |
| Match info | Scoring mode label (BASIC / ONLY_CASTLES) | Static |
| Speed indicator | Current speed preset name or "Custom" | Static |
| Winning score | Target score if set (e.g., "First to 100") | Static |

#### Player Score Cards

Each player gets a card showing:

| Element | Content | Update |
|---------|---------|--------|
| Player name | Configured name + color indicator | Static |
| Score | Current accumulated score | On each EventLog |
| Castles owned | Current count (with bonus indicator if over max) | On each EventLog |
| Actions taken | Count / max (if max_actions > 0) | On each action |
| Ranking indicator | Position (1st, 2nd, 3rd...) | On score change |
| Status | Active / At limit (bonus castles) / Max actions reached | On state change |

Cards are sorted by current ranking (highest score at top) and reorder in real-time with smooth animation.

#### Color Coding

Player cards use the same color as their castles on the board:
- Background tint or left-border stripe in player color
- Score text in white/black for contrast
- "At limit" status shown with a warning color (amber)
- Bonus castle count shown with star icon

#### Point Popups

When points are scored, a floating number appears near the relevant cell on the board:

| Event | Popup | Color |
|-------|-------|-------|
| `capture_empty` | `+N` | Actor's color |
| `increment_contagion` | `+N` | Actor's color (subdued) |
| `capture_contagion` | `+N` (actor) and `-N` (target, separate popup) | Actor's color / target's color |
| `destroy_own_castle` | — (no popup) | — |

Popups float upward and fade over ~1 second. Multiple popups stack vertically to avoid overlap.

#### End-of-Match Summary Screen

Displayed at Match Flow COMPLETE state:

```
┌────────────────────────────────────┐
│         MATCH COMPLETE             │
│                                    │
│   🏆 Winner: [Player Name]        │
│   End reason: [Time/Score/etc.]    │
│                                    │
│   RANKINGS                         │
│   1st  PlayerA    285 pts  12🏰   │
│   2nd  PlayerB    201 pts   8🏰   │
│   3rd  PlayerC    156 pts   6🏰   │
│   4th  CPU-Hard    89 pts   3🏰   │
│                                    │
│   STATISTICS                       │
│   Duration: 3:00                   │
│   Total captures: 47               │
│   Longest chain: 6 (PlayerA)       │
│                                    │
│   [REMATCH]  [CHANGE SETTINGS]     │
│              [EXIT TO MENU]        │
└────────────────────────────────────┘
```

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Hidden** | Application start (menus) | Match starts | HUD not visible |
| **Active** | Match PLAYING | Match ends | Displaying live scores, timer, popups |
| **Paused** | Pause triggered | Unpause | HUD visible but timer frozen, "PAUSED" overlay |
| **Summary** | Match COMPLETE | User selects an option | End-of-match summary screen |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Match Flow** | Reads | Per-player state (scores, castles, actions, bonus stacks), match timer, match lifecycle events |
| **Scoring System** | Indirect only | HUD reads pre-computed scores from Match Flow, does not call Scoring System directly |
| **Game Config** | Reads | Player names, colors, scoring mode, time_limit, winning_score, max_actions, max_castles |
| **Board Renderer** | Sibling | Shares viewport — HUD wraps around board area |
| **Input System** | Reads (Summary state) | User input for rematch/exit selection |
| **Scene Management** | Signals | "Exit to menu" triggers scene transition |

## Formulas

### Timer Display

```
format_timer(time_limit: int, elapsed: float) -> String:
    if time_limit > 0:
        // Countdown mode
        remaining = max(0, time_limit - elapsed)
        minutes = int(remaining) / 60
        seconds = int(remaining) % 60
        return "%d:%02d" % [minutes, seconds]
    else:
        // Count-up mode (no time limit)
        minutes = int(elapsed) / 60
        seconds = int(elapsed) % 60
        return "Elapsed: %d:%02d" % [minutes, seconds]
```

### Ranking Sort

```
sort_player_cards(players):
    // Same criteria as Match Flow tiebreaking
    sort by score descending, then castles, then captures, then actions ascending
```

### Popup Positioning

```
popup_position(grid_index, board_origin, cell_size):
    cell_pos = board_renderer.cell_position(grid_index)
    return cell_pos + Vector2(cell_size / 2, -10)  // centered above cell
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| 8 players — score cards don't fit vertically | Use compact card layout (smaller font, abbreviated stats) for 5+ players | Readability at all player counts |
| Score exceeds 4 digits (>9999) | Allow text to expand or use abbreviated format (10.2k) | Extreme configs with high multipliers |
| Negative score | Display with minus sign, no special formatting | Valid game state |
| Timer reaches 0 | Display "0:00" and freeze (match ending handled by Match Flow) | Visual confirmation time is up |
| No time limit (time_limit = 0) | Show count-up timer "Elapsed: M:SS" instead of countdown | Still useful information |
| No winning score (winning_score = 0) | Omit "First to X" from top bar | Don't show irrelevant info |
| Many point popups in rapid chain | Stack vertically, oldest fade first | Prevent popup pile-up |
| Player at max_castles | Card shows "AT LIMIT" status in amber, castle count shows bonus indicator | Clear visual feedback of constraint |
| Draw at match end | Summary shows "DRAW" instead of winner, tied players share rank | Valid outcome |
| Rematch selected | HUD resets to Active state with zeroed scores | Quick restart |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Match Flow** | This depends on Match Flow | Reads all per-player state and match lifecycle (hard) |
| **Game Config** | This depends on Game Config | Player info, match settings for display (hard) |
| **Board Renderer** | This depends on Board Renderer | Reads `cell_position()` for popup positioning; shares viewport space (hard) |
| **Input System** | This depends on Input System | Summary screen navigation (soft) |
| **Scene Management** | Scene Management depends on this | Exit-to-menu signal (soft) |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| Popup duration | 1.0s | 0.3–2.0 | Popups linger longer — more readable | Popups flash quickly — less clutter |
| Popup float distance | 30px | 10–60 | Popups travel further upward | Subtle movement |
| Card reorder animation | 0.3s | 0.1–0.5 | Smooth ranking changes | Snappy reordering |
| Compact mode threshold | 5 players | 4–6 | Compact layout triggers earlier | More space before compacting |

These are renderer-internal tuning values, not in Game Config.

## Acceptance Criteria

- [ ] Timer displays correct countdown (or count-up when no time limit)
- [ ] Timer freezes at 0:00 when time expires
- [ ] All player score cards display with correct color coding
- [ ] Scores update in real-time from Match Flow EventLogs
- [ ] Castle count updates on captures and destroys
- [ ] Action count shows current/max when max_actions is set
- [ ] Player cards reorder by ranking with smooth animation
- [ ] "AT LIMIT" status shown when player is at max_castles
- [ ] Bonus castle count visible with star indicator
- [ ] Point popups appear near correct board cell
- [ ] Positive popups in actor's color, negative in target's color
- [ ] Multiple popups stack without overlapping
- [ ] Popups fade after ~1 second
- [ ] End-of-match summary shows correct winner, rankings, and statistics
- [ ] Draw displayed correctly when scores are tied
- [ ] Rematch/Change Settings/Exit buttons functional in summary
- [ ] HUD layout adapts for 2-4 players (one panel) vs 5-8 (two panels)
- [ ] Compact card layout activates at 5+ players
- [ ] Scoring mode and winning score displayed in top bar
- [ ] No HUD elements overlap the game board
