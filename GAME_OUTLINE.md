# Crystal Kingdoms 3JS

A strategic turn-based grid game. Compete to capture castles through quick reflexes and tactical decisions in a dynamic contagion-based combat system.

## Overview

Crystal Kingdoms is a multiplayer game where players race to capture castles on a grid board. The game combines reaction speed with strategy, featuring:

- **Cursor-based action system**: A cursor spawns randomly on the board, and the first player to act gains control
- **Contagion mechanics**: Repeatedly attack enemy castles to build up contagion and eventually capture them
- **Castle ownership**: Captured castles score points and can be destroyed by their owners
- **Chain actions**: Actions can chain across the board in a direction, affecting multiple castles
- **Configurable gameplay**: Adjust board size, scoring modes, capture thresholds, and more

#### Event-Driven Resolution

The rules engine produces deterministic event logs alongside state changes with these details:
    EventTypes: 'capture_empty' | 'increment_contagion' | 'capture_contagion' | 'destroy_own_castle' | 'chain_ended'
    GridIndex?: number;
    ActorId?: PlayerId;
    PointsDelta?: number;

This enables:
- Predictable testing and debugging
- Replay and undo functionality
- Animation and visual effects tied to events
- Separation of game logic from presentation

## Game Mechanics

### Board

- Grid sizes from 6x6 to 12x12 (Godot version; original was 4x4 to 8x8)
- Each cell is a castle that can be owned by a player or remain empty
- Optional wrap-around at board edges

### Actions

1. **Cursor Spawn**: A cursor appears on a random empty castle
2. **Player Action**: The first player to act gains control of the cursor
3. **Action Types**:
   - **Tap/Fire**: Act on the current castle only
   - **Swipe/Direction**: Chain action in a direction (up, down, left, right)

### Resolution Rules

When an action targets a castle:

- **Empty Castle**: Captured by the acting player
- **Enemy Castle**: Increment contagion counter for the acting player
  - When contagion reaches the capture threshold, the castle is captured
- **Own Castle**: Destroyed (ownership cleared)

### Chain Actions

When a direction is provided:
1. Start at the cursor castle
2. Apply action to current castle
3. If the action doesn't end the chain (empty capture or own castle destruction), move to the next castle in the direction
4. Repeat until chain ends

### Scoring Modes

#### Basic Mode
- Points for capturing empty castles (based on adjacent owned castles)
- Points for contagion gain
- Points lost when losing a castle

#### Only Castles Mode
- Points only for castle captures
- No points for contagion gain
- Points lost when losing a castle (based on contagion level)

#### Curve-Based Scoring (Godot Version)

All point values use a selectable progression curve rather than flat values. Available curves:
- **Power of Two** (2^(n-1)): 1, 2, 4, 8, 16 — exponential growth
- **Count** (n): 1, 2, 3, 4, 5 — linear progression
- **Fibonacci** (fib(n+1)): 1, 2, 3, 5, 8 — accelerating streaks
- **Square** (n²): 1, 4, 9, 16, 25 — aggressive snowball
- **Custom**: user-defined values per step

Each scoring parameter has: curve selector, multiplier (float), and adjustment (float additive).
Effective value: `max(1, round(curve(n) * multiplier + adjustment))` — minimum 1 point, round half up.

- **Adjacency bonus** (empty capture): default Power of Two, multiplier 1.0
- **Contagion gain**: default Count, multiplier 1.0
- **Castle capture**: default Square, multiplier 1.2
- **Castle lost**: bases value on another scorer (default: capture), multiplier 1.5

The UI should display effective values for n=1..5 alongside curve and multiplier selections.

### Constraints

- **Max Actions**: Limit on total actions per player
- **Max Castles**: Limit on simultaneously owned castles

## Testing

The project includes/wil-include comprehensive unit tests covering:

- Board creation and navigation
- Action resolution logic
- Contagion mechanics
- Scoring calculations
- Constraint enforcement

## Documentation

Additional documentation can be found in the `docs/` directory:
- `mvp-plan.md`: Detailed MVP implementation plan and game mechanics

## Future Plans

- 3D rendering for visual representation
- CPU AI with configurable difficulty
- Match timer and win conditions
- Options menu for game configuration
- Controller and input remapping
- Online multiplayer support

## License

Private project.
