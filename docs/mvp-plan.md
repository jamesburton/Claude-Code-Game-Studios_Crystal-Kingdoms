# Crystal Kingdoms — MVP Plan

## Is this enough to start?

Yes — this outline is strong enough to begin MVP development. The key mechanics, options, and scoring logic are already defined at a level that can be implemented in vertical slices.

## MVP Goal

Deliver a playable single-match prototype that validates:

- Core turn/action loop (cursor spawn, player action, chain resolution)
- Castle ownership and contagion mechanics
- Basic scoring and win conditions
- Local human + CPU participation
- Configurable grid size and a small subset of options

## Suggested MVP Scope (Phase 1)

### In scope

1. **Board + State Model**
   - Grid sizes: 4x4 to 8x8
   - Castle ownership (`null | playerId`)
   - Per-castle contagion map by player
   - Cursor position + active flag
   - 2D version using the the images in the '../images' folder

2. **Action System**
   - Spawn cursor on random empty castle after random delay
   - First actor wins the action opportunity
   - Tap/fire = act on current castle
   - Swipe/direction = chain action in direction
   - Wrap around board edges (option toggle can come in Phase 2)

3. **Resolution Rules**
   - Empty castle => capture by actor
   - Enemy castle => increment actor contagion and continue
   - Own castle => destroy castle (ownership cleared)
   - If contagion reaches capture threshold => capture and reset others' contagion on that castle

4. **Scoring**
   - Implement **Basic** scoring first
   - Add **Only Castles** as second mode if schedule allows

5. **Match End Conditions**
   - Time limit
   - Winning score
   - End match when either condition is met

6. **CPU (Simple)**
   - Reaction delay window based on difficulty
   - Random directional choice with mild bias toward nearby enemy/empty castles

7. **Input Configuration & Player Setup**
   - Multiple human players (local multiplayer)
   - Customizable player names (override defaults like "Player 1")
   - Flexible input device selection per player:
     - Keyboard (shared or individual keys)
     - Gamepad/joystick (individual controllers)
   - Custom button/key mapping per player
   - Settings persistence via browser localStorage
   - Menu screens for player setup and input configuration
   - Input conflict detection (same key bound to multiple players)
   - Gamepad connection/disconnection handling

### Out of scope for first MVP cut

- Advanced AI strategies
- Full polish/FX pass
- Large options menu UX polish (beyond player setup and game options)
- Networking/online play
- Cloud save/sync (only local storage)

## Architecture Proposal

## 1) Core Domains

- **GameConfig**: options and tunables
- **MatchState**: current board, players, score, timer, action counts
- **RulesEngine**: deterministic action/capture/scoring logic
- **TurnDirector**: cursor timing, input race, action execution lifecycle
- **CPUController**: AI decision + timing
- **InputManager**: input device handling, key/button mapping, player input routing
- **SettingsManager**: localStorage persistence for input configs and player settings
- **MenuSystem**: UI for player setup, input configuration, game options
- **Renderer/UI**: Three.js visuals + HUD

## 2) Data Structures

To be defined in .cs, but a prior implementation in TypeScript used the following which we can adapt:

```ts
export type PlayerId = string;

export interface CastleState {
  owner: PlayerId | null;
  contagion: Record<PlayerId, number>; // missing key = 0
}

export interface BoardState {
  size: number; // 4..8
  cells: CastleState[]; // length = size * size
}

export interface PlayerState {
  id: PlayerId;
  name: string;
  color: string;
  isCpu: boolean;
  difficulty?: "easy" | "medium" | "hard";
  score: number;
  castlesOwned: number;
  actionsStarted: number;
}

export interface PlayerInputConfig {
  playerId: PlayerId;
  name: string; // Customizable player name
  inputType: 'keyboard' | 'gamepad';
  keyboardBindings?: {
    up: string;
    down: string;
    left: string;
    right: string;
    fire: string;
  };
  gamepadIndex?: number; // Which gamepad (0-3)
  gamepadBindings?: {
    up: number;
    down: number;
    left: number;
    right: number;
    fire: number;
  };
}

export interface InputSettings {
  version: number;
  players: PlayerInputConfig[];
}
```

## 3) Deterministic Rules Contract

This makes balancing and testing much easier.

## Implementation Plan (Milestones)

### Milestone 1 — Playable Core Loop

- Build board state + rendering placeholders
- Spawn cursor + accept first input
- Implement action resolution chain
- Show ownership colors and contagion values

### Milestone 2 — Scoring + Match Flow

- Add basic scoring table
- Add timer + win-score checks
- Add end-of-match summary

### Milestone 3 — Options + CPU

- Configurable options subset:
  - grid size
  - time limit
  - winning score
  - capture contagion
  - speed preset
- Add simple CPU actors and difficulties

### Milestone 4 — Input Configuration & Menu System

- **Input Manager**:
  - Keyboard event handling with customizable key bindings
  - Gamepad API integration (poll gamepads, handle connect/disconnect)
  - Input conflict detection and validation
  - Per-player input routing based on configuration

- **Settings Manager**:
  - localStorage read/write utilities
  - Input settings schema (versioned for future compatibility)
  - Default configurations (Player 1 on WASD+Space, etc.)
  - Settings validation and migration

- **Menu System UI**:
  - Main Menu screen
  - Player Setup screen:
    - Add/remove players (2-4 players)
    - Configure player name, color, type (human/CPU)
  - Input Configuration screen (per player):
    - Select input device (keyboard/gamepad)
    - Customize button/key mappings
    - Test bindings (visual feedback)
    - Detect conflicts, show warnings
  - Game Options screen:
    - Board size, scoring mode, time limit, etc.
  - Save/cancel/reset functionality

- **Tests**:
  - Input manager key/gamepad mapping
  - Settings serialization/deserialization
  - Conflict detection logic

### Milestone 5 — MVP Hardening

- Add tests for rules engine
- Tune delays and values
- Improve readability (HUD, score panel, current actor indicators)
- Integration testing with multiple input configurations
- Gamepad compatibility testing

## Rules Clarifications (Resolved)

The following gameplay clarifications are now locked:

1. **Adjacency** is orthogonal only (no diagonals), and actions also do not traverse diagonals.
2. **Chain scoring timing** is step-by-step during chain traversal (fast/moderate cursor movement), with each score shown as it occurs.
3. If wrap-around is disabled, a chain stops at the board edge; if enabled, the chain continues and wraps until it reaches an empty castle or one of the actor's own castles.
4. In **Only Castles** mode, contagion gain scoring remains `0`.
5. If time runs out while a chain is processing, the current chain still completes before the match ends.

For implementation detail on (2): this means event production should remain per-step and deterministic in the rules engine, while UI timing/animation consumes those events at display speed.

## Test Plan (MVP)

- Unit tests for resolving actions covering:
  - Empty capture
  - Enemy contagion increments and capture threshold conversion
  - Own-castle destroy case
  - Score gain/loss table
  - Max-castles and max-actions constraints
- Simulation test: run 1,000 CPU-only matches to catch deadlocks or invalid states.
- Snapshot/integration test: board serialization remains valid across turns.

## Current Build Progress

### ✅ Completed Milestones

**Milestone 1 — Core Game State & Rules Engine**
- ✅ Core state types and board helpers implemented
- ✅ Deterministic rules engine with contagion/capture and scoring
- ✅ Action-start constraints (`maxActions`, `maxCastles`) implemented
- ✅ Match-end helpers including "complete current chain even on timeout"
- ✅ Turn director state machine for cursor spawn, claim racing, timeout/expiry

**Milestone 2 — Game Loop & Event System**
- ✅ Game loop orchestrator integrating turn director, rules, and match flow
- ✅ Event emission system for renderer integration
- ✅ Time-based match completion and winning conditions

**Milestone 3 — CPU AI & Input System**
- ✅ CPU controller with difficulty-based AI (easy/medium/hard)
- ✅ Strategic decision-making with bias toward empty/enemy castles
- ✅ Input interface with validation and action queuing
- ✅ Renderer interface for visual state extraction and event bus

**Milestone 4 — Input Configuration & Settings**
- ✅ Settings manager with localStorage persistence
- ✅ Input manager with keyboard and gamepad support
- ✅ Customizable player controls (WASD, arrows, IJKL, numpad)
- ✅ Conflict detection and validation for key bindings

**Milestone 5 — Integration Testing & Quality Assurance**
- ✅ Comprehensive integration tests (CPU vs CPU, mixed matches)
- ✅ Stress testing (100 matches, >95% completion rate)
- ✅ Time limit expiry verification
- ✅ State validation throughout match lifecycle
- ✅ **178 tests passing** across 13 test files

### 📋 Remaining Work

**UI & Rendering (Next Phase)**
- Menu system UI (main menu, player setup, input configuration)
- Visual feedback and animations
- HUD, score panel, current actor indicators

## Immediate Next Steps

1. **UI Development**: Build menu system for player configuration
2. **Renderer Integration**: Connect Three.js renderer to game loop
3. **Polish & Tuning**: Fine-tune timing values and visual feedback
4. **Production Build**: Bundle and deploy for web
