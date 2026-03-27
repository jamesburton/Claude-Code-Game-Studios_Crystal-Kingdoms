# ADR-0001: Event-Driven Game Loop with Strict Mutation Rules

## Status
Accepted

## Date
2026-03-27

## Context

### Problem Statement
Crystal Kingdoms has a complex action resolution pipeline: player input → claim racing → action resolution → chain traversal → scoring → animation → respawn cycle. Multiple systems need to react to game state changes (renderer, HUD, audio, match flow). We need an architecture that keeps game logic deterministic and testable while allowing presentation systems to animate state changes at their own pace.

### Constraints
- Game logic must be deterministic for testing and potential replay support
- Chain animations must play step-by-step at configurable speed, separate from logic resolution
- Multiple presentation systems (Board Renderer, HUD, Audio) consume the same state changes
- Board State is the central shared data structure — concurrent uncontrolled mutations would cause bugs

### Requirements
- Must support deterministic testing (same inputs → same outputs)
- Must separate logic resolution timing from animation timing
- Must allow multiple observers to react to state changes independently
- Must prevent accidental Board State corruption from unauthorized systems

## Decision

**Event-driven architecture with strict mutation ownership.**

### 1. EventLog as the sole Rules→Presentation interface

The Rules Engine resolves actions as pure functions, producing an ordered EventLog alongside Board State mutations. The EventLog is the **only** interface between game logic and presentation:

```
Rules Engine: (BoardState, GameConfig, Action) → (BoardState', EventLog)
```

Presentation systems (Board Renderer, HUD, Audio) consume EventLog events to drive animations, score displays, and sound effects. They never read the resolution logic directly — only the event stream.

### 2. Board State mutation ownership

Only two systems may mutate Board State:
- **Rules Engine**: cell ownership, contagion counters (during action resolution)
- **Turn Director**: cursor position and active state (during spawn/claim/expire)

All other systems have read-only access. This is enforced by convention (documented in GDDs), not by language-level access control in GDScript.

### 3. Animation completion signaling

The Turn Director waits for the Board Renderer's `animation_complete` signal before starting the cursor respawn timer. This decouples resolution speed from animation speed:

```
Turn Director → Rules Engine (resolve) → EventLog broadcast
Board Renderer (animate EventLog) → animation_complete signal → Turn Director (start respawn timer)
```

### Architecture Diagram

```
                    ┌─────────────┐
                    │ Turn Director│ (orchestrator)
                    └──────┬──────┘
                           │ action request
                    ┌──────▼──────┐
                    │ Rules Engine │ (pure logic)
                    └──────┬──────┘
                           │ EventLog
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌───────────┐ ┌────────┐ ┌───────────┐
        │Board      │ │Match   │ │HUD / Audio│
        │Renderer   │ │Flow    │ │(future)   │
        └─────┬─────┘ └────────┘ └───────────┘
              │
              │ animation_complete
              ▼
        Turn Director (respawn timer starts)
```

### Key Interfaces

**Event struct:**
```
Event:
    type: EventType       # capture_empty | increment_contagion | capture_contagion | destroy_own_castle | chain_ended
    grid_index: int
    actor_id: PlayerId
    points_delta: int
    target_owner: PlayerId?
    target_points_lost: int
    contagion_level: int?
    chain_position: int
```

**Board State mutation contract:** Only Rules Engine and Turn Director call setters on Board State. All other systems use read-only getters.

**Animation signal:** Board Renderer emits `animation_complete` (Godot signal) after processing all events in an EventLog.

## Alternatives Considered

### Alternative 1: Direct State Observation (polling)
- **Description**: Presentation systems poll Board State each frame and diff against previous state to detect changes
- **Pros**: Simpler — no event system needed
- **Cons**: Cannot animate step-by-step chains (all changes appear at once); no information about *why* a change happened (was it a capture or contagion?); O(n) diff cost per frame
- **Rejection Reason**: Chain animation is core to the game feel — polling cannot support sequential step-by-step animation

### Alternative 2: Observer Pattern on Board State
- **Description**: Board State emits signals for every field change (ownership_changed, contagion_changed, etc.)
- **Pros**: Fine-grained reactivity; Godot signals are native and efficient
- **Cons**: Loses action context (signals don't know they're part of a chain); ordering between signals is fragile; tight coupling between Board State and all observers
- **Rejection Reason**: EventLog preserves full action context (actor, chain position, points) that individual property signals would lose

### Alternative 3: Command Pattern (undoable)
- **Description**: All mutations are Command objects with execute/undo methods, stored in a history stack
- **Pros**: Full undo/redo support; replay for free
- **Cons**: Over-engineered for MVP; adds complexity to every mutation; undo semantics for contagion are non-trivial
- **Rejection Reason**: EventLog provides replay capability without undo complexity. Can migrate to Command pattern later if undo is needed.

## Consequences

### Positive
- Deterministic testing: Rules Engine can be tested as a pure function with no presentation dependencies
- Clean animation: EventLog drives step-by-step chain animation at configurable speed
- Multiple observers: Any number of systems can consume the same EventLog (renderer, HUD, audio, analytics)
- Replay potential: EventLog stream can be recorded and replayed

### Negative
- Rules Engine must compute all scoring in-line (cannot defer to presentation layer)
- Board Renderer must queue and sequence animations — adds complexity vs. simple polling
- Two mutation owners (Rules Engine + Turn Director) requires discipline to maintain

### Risks
- **Risk**: A new system accidentally mutates Board State directly
  - **Mitigation**: Document mutation rules in Board State GDD; code review catches violations
- **Risk**: Animation queue backs up under FRANTIC speed preset
  - **Mitigation**: Board Renderer compresses animation timing when queue depth exceeds threshold

## Performance Implications
- **CPU**: Minimal — EventLog is a small array of structs per action (typically 1-12 events). No per-frame cost.
- **Memory**: Negligible — EventLog is transient (created per action, consumed, discarded). No accumulation.
- **Load Time**: None — no precomputation needed.

## Migration Plan
No existing code to migrate — this is a greenfield architectural decision.

## Validation Criteria
- Rules Engine tests pass without any presentation system initialized
- Chain animations play step-by-step at `chain_step_delay` intervals
- Turn Director respawn timer starts only after `animation_complete` signal
- No Board State mutations from systems other than Rules Engine and Turn Director (verified by code review)

## Related Decisions
- [ADR-0002: Data-Driven Configuration via Godot Resources](adr-0002-data-driven-config.md)
- [Rules Engine GDD](../../design/gdd/rules-engine.md)
- [Board State GDD](../../design/gdd/board-state.md)
- [Turn Director GDD](../../design/gdd/turn-director.md)
- [Board Renderer GDD](../../design/gdd/board-renderer.md)
