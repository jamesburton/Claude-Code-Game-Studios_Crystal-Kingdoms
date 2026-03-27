# Board Renderer

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-27
> **Implements Pillar**: Presentation — visual representation of the game board

## Overview

The Board Renderer draws the Crystal Kingdoms game board as a 2D grid using Godot's Node2D scene system. It displays castles (using the existing 64×64 pixel sprites), ownership colors, contagion indicators, the cursor, and bonus castle markers. It consumes EventLogs from Match Flow to animate state changes — captures, contagion ticks, chain traversal, and destruction. The renderer reads from Board State but never modifies it; all visual state is derived, not stored.

## Player Fantasy

The board should feel like a living battlefield. Castles visibly change hands with satisfying color transitions. Contagion should feel like a creeping threat — visible counters ticking up toward the capture threshold. Chain actions should sweep across the board with readable, sequential animation. The cursor should draw the eye when it spawns — "there it is, GO!" Bonus castles should sparkle or twinkle to show they're excess. The overall aesthetic is clean, colorful, and readable even at 12×12 with 8 player colors.

## Detailed Rules

### Core Rules

#### Scene Structure

```
BoardRenderer (Node2D)
├── GridContainer (Node2D) — positions cells in a grid
│   ├── CastleCell_0 (Sprite2D + Label) — cell index 0
│   ├── CastleCell_1
│   ├── ... (grid_size² cells total)
│   └── CastleCell_N
├── CursorSprite (Sprite2D) — overlay on active cursor cell
└── ChainLine (Line2D or custom) — visual trail during chain resolution
```

#### Cell Rendering

Each cell displays:

| Element | Visual | Source |
|---------|--------|--------|
| Castle sprite | 64×64 PNG from `images/` folder | `Basic Castle Start [Color].png` for owned, `Basic Castle Start.png` for empty |
| Ownership color | Sprite selection based on owner's color | `player.color` → sprite file mapping |
| Contagion indicator | Small gem sprites (6×6) or numeric overlay showing contagion levels per threatening player | `cell.contagion` dictionary |
| Bonus marker | Star/twinkle overlay sprite or shader effect | Player's `bonus_stack` contains this cell index |
| Cell highlight | Subtle border or glow for special states | Context-dependent (cursor target, chain path) |

#### Sprite-to-Color Mapping

| Player Color | Castle Sprite | Gem Sprite |
|-------------|---------------|------------|
| Blue | `Basic Castle Start Blue.png` | `6x6 Gem Blue.png` |
| Green | `Basic Castle Start Green.png` | `6x6 Gem Green.png` |
| Orange | `Basic Castle Start Orange.png` | `6x6 Gem Orange.png` |
| Red | `Basic Castle Start Red.png` | `6x6 Gem Red.png` |
| Yellow | `Basic Castle Start Yellow.png` | `6x6 Gem Yellow.png` |
| Purple | `Basic Castle Start Purple.png` | `6x6 Gem Purple.png` |
| Cyan | `Basic Castle Start Cyan.png` | `6x6 Gem Cyan.png` |
| Magenta | `Basic Castle Start Magenta.png` | `6x6 Gem Magenta.png` |
| (empty) | `Basic Castle Start.png` | — |

#### Cursor Rendering

- Uses `Cursor 64x64.png` sprite
- Positioned over the active cursor cell
- Visible only when `board.cursor_active = true`
- Should pulse or animate to draw attention (simple scale oscillation or glow)
- Disappears immediately when cursor is claimed

#### Contagion Display

For each cell, show which players have contagion and how much:

- **Option A (gems)**: Place small colored gems (6×6) around the castle sprite, one per player with contagion. Number of gems or a small counter indicates level.
- **Option B (numeric)**: Small colored numbers overlaid on cell corners showing contagion level per player.
- **Recommended**: Start with Option B for clarity (numbers are unambiguous), with gem sprites as visual flavor. The specific visual treatment can be refined during polish.

Contagion display should clearly communicate "how close to capture" — consider showing `level/threshold` (e.g., "2/3").

#### Grid Scaling

The board must fit the viewport regardless of grid size:

```
cell_display_size = min(viewport_width, viewport_height) / grid_size
scale_factor = cell_display_size / 64.0  // base sprite is 64×64
```

For a 1920×1080 viewport:
- 6×6 grid: ~170px per cell (scaled up, may need higher-res assets later)
- 8×8 grid: ~128px per cell (2× scale, looks good)
- 12×12 grid: ~85px per cell (slightly scaled up from 64px, tight but readable)

Grid is centered in the viewport with padding for the HUD.

#### Event-Driven Animation

The renderer consumes EventLogs broadcast by the Turn Director and plays animations sequentially. When all animations for an EventLog complete, the renderer emits an `animation_complete` signal that the Turn Director listens for before starting the respawn timer.

Animations per event type:

| Event Type | Animation | Duration |
|------------|-----------|----------|
| `capture_empty` | Castle sprite swaps to actor's color, brief flash/pulse | 0.2s |
| `increment_contagion` | Contagion counter ticks up with small bounce, gem appears/grows | 0.15s |
| `capture_contagion` | Dramatic color swap, contagion indicators clear, screen shake (subtle) | 0.3s |
| `destroy_own_castle` | Castle fades/crumbles to empty sprite | 0.25s |
| `chain_ended` | Chain trail fades out | 0.2s |

Chain animations play sequentially at `chain_step_delay` intervals (from Game Config), matching the Rules Engine's step-by-step resolution.

#### Chain Visualization

During chain resolution, show the traversal path:
- Highlight the current cell being resolved
- Draw a trail (Line2D or connected highlights) showing the chain path so far
- Each step animates at `chain_step_delay` pace
- Trail fades after chain ends

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Initializing** | Match SETUP | Board created and rendered | Create cell sprites, position grid |
| **Idle** | No events to process | EventLog received or cursor spawns | Display current board state, await events |
| **Animating** | EventLog received | All events animated | Play animations sequentially |
| **Transitioning** | Match ends | Transition complete | Fade or visual transition to results |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board State** | Reads | Full board state for rendering (ownership, contagion, cursor) |
| **Match Flow** | Reads events + state | EventLogs for animation (via Turn Director broadcast), match lifecycle signals, per-player `bonus_stack` for bonus castle markers |
| **Game Config** | Reads | `grid_size` for layout, `chain_step_delay` for animation timing, player colors |
| **HUD / Score Panel** | Sibling | Shares viewport space — board is centered, HUD surrounds it |
| **Animation/VFX** | VFX enhances this | Post-V1: particle effects, screen shake, advanced transitions |

## Formulas

### Grid Layout

```
cell_size = min(board_area_width, board_area_height) / grid_size
grid_origin_x = (viewport_width - cell_size * grid_size) / 2
grid_origin_y = (viewport_height - cell_size * grid_size) / 2 + hud_offset

cell_position(index):
    row = index / grid_size
    col = index % grid_size
    x = grid_origin_x + col * cell_size
    y = grid_origin_y + row * cell_size
    return (x, y)
```

### Animation Timing

```
total_chain_animation_time = chain_length * config.chain_step_delay
event_animation_start(chain_position) = chain_position * config.chain_step_delay
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| 12×12 grid with 8 players | All 8 colors must be visually distinct at ~85px cell size | Color palette chosen for maximum contrast |
| Contagion from 7 players on one cell | Display up to 7 contagion indicators without overlapping | Layout contagion indicators in consistent positions around the cell |
| Rapid successive events (FRANTIC preset) | Animations may overlap — queue them and play at speed | Don't skip animations; compress timing if needed |
| Window resize during match | Recalculate grid layout, reposition all cells | Responsive layout |
| Cell has both bonus marker and high contagion | Both indicators visible simultaneously | Layer: castle sprite → contagion indicators → bonus marker |
| Chain traverses entire row (12 cells) | Chain animation plays for 12 × chain_step_delay seconds | Long but readable at normal/fast speeds |
| Empty board (all cells unowned) | Show all empty castle sprites | Valid state at match start |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Board State** | This depends on Board State | Reads full board for rendering (hard) |
| **Match Flow** | This depends on Match Flow | EventLogs for animation, lifecycle signals (hard) |
| **Game Config** | This depends on Game Config | Grid size, timing, player colors (hard) |
| **Animation/VFX** | Animation/VFX depends on this | Enhances visual feedback (soft — works without VFX system) |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `chain_step_delay` | 0.2s | 0.05–1.0 | Chain traversal more readable | Chain feels instant |
| Animation durations | 0.15–0.3s | 0.05–0.5 | More dramatic visual feedback | Snappier, less visible |
| Grid padding | 10% viewport | 5–20% | More space for HUD | Board fills more screen |

Animation durations are renderer-internal tuning, not in Game Config. `chain_step_delay` is from Game Config.

## Acceptance Criteria

- [ ] Board renders correct number of cells for all grid sizes 6–12
- [ ] All 8 player colors display with correct castle sprites
- [ ] Empty cells display the neutral castle sprite
- [ ] Cursor sprite appears on correct cell when cursor is ACTIVE
- [ ] Cursor disappears immediately on claim
- [ ] Cursor pulses or animates to attract attention
- [ ] Contagion indicators show correct levels per player per cell
- [ ] Contagion display shows level/threshold for readability
- [ ] Bonus castle markers (star/twinkle) visible on excess castles
- [ ] `capture_empty` animation: color swap with flash
- [ ] `increment_contagion` animation: counter tick with bounce
- [ ] `capture_contagion` animation: dramatic color swap, contagion clear
- [ ] `destroy_own_castle` animation: fade to empty
- [ ] Chain animations play sequentially at `chain_step_delay` intervals
- [ ] Chain trail visible during traversal, fades after completion
- [ ] Grid scales correctly to fit viewport at all grid sizes
- [ ] Grid remains centered with HUD space reserved
- [ ] 8 player colors are visually distinct at smallest cell size (~85px for 12×12)
- [ ] No rendering artifacts when board state changes rapidly
