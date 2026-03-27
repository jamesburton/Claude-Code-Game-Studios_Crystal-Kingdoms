# Input System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-27
> **Implements Pillar**: Foundation — routes player input to game actions

## Overview

The Input System translates raw keyboard and gamepad inputs into game actions (tap, swipe direction) and routes them to the correct player. It supports 2-8 local players sharing keyboards or using individual gamepads, with fully customizable key/button bindings per player. It does not decide what happens when an action is taken — it only reports "Player X performed action Y" to the Turn Director. During menus, it routes UI navigation inputs instead.

## Player Fantasy

The input system is felt through responsiveness and fairness. In a cursor-racing game, input latency is the difference between winning and losing the claim. The fantasy is that the controls feel instant and precise — "I pressed it first and I got it." Multiple players sharing a keyboard should feel no disadvantage compared to gamepad users.

## Detailed Rules

### Core Rules

#### Input Actions

The Input System produces these game actions:

| Action | Meaning | Input Pattern |
|--------|---------|---------------|
| `FIRE` | Tap — act on cursor cell only | Fire button press |
| `SWIPE_UP` | Chain action upward | Up + Fire simultaneously, or Up alone (configurable) |
| `SWIPE_DOWN` | Chain action downward | Down + Fire, or Down alone |
| `SWIPE_LEFT` | Chain action left | Left + Fire, or Left alone |
| `SWIPE_RIGHT` | Chain action right | Right + Fire, or Right alone |

**Input mode option** (per player, stored in Game Config):
- **Fire-required mode** (default): Direction buttons queue a direction; fire button triggers the action with that direction. Tap fire with no direction = tap action.
- **Direct mode**: Direction buttons immediately trigger a swipe action. Fire button = tap action. Faster but less deliberate.

#### Per-Player Bindings

Each human player has a binding configuration. Bindings are **per-action, per-device** — a single player can mix keyboard keys and gamepad buttons freely, and two players can share a single gamepad.

```
Binding:
    device_type: KEYBOARD | GAMEPAD_BUTTON | GAMEPAD_AXIS
    device_index: int       // which gamepad (0-7); ignored for KEYBOARD in MVP
    key_or_button: int      // scancode, button index, or axis index
    axis_direction: int     // +1 or -1 for GAMEPAD_AXIS (e.g., stick up vs down)

PlayerInput:
    player_id: PlayerId
    input_mode: FIRE_REQUIRED | DIRECT
    bindings:
        up: Binding
        down: Binding
        left: Binding
        right: Binding
        fire: Binding
```

Each action binding is independent — there is no "device per player" constraint. This enables:
- Player A on WASD + Space (keyboard)
- Player B on gamepad 0 d-pad + A button (full gamepad)
- Player C on gamepad 0 face buttons (Y=up, A=down, X=left, B=right) + R1 (shared gamepad with Player B)
- Player D on gamepad 1 d-pad (rotated 90°) + L1 (creative ergonomic setup)

#### Default Keyboard Bindings

| Player | Up | Down | Left | Right | Fire |
|--------|-----|------|------|-------|------|
| Player 1 | W | S | A | D | Space |
| Player 2 | Up | Down | Left | Right | Enter |
| Player 3 | I | K | J | L | H |
| Player 4 | Numpad 8 | Numpad 5 | Numpad 4 | Numpad 6 | Numpad 0 |

Players 5-8 have no default keyboard bindings — they must use gamepads or be configured manually.

#### Default Gamepad Bindings (per gamepad, one player per pad)

| Input | Button |
|-------|--------|
| Up | D-pad Up / Left Stick Up |
| Down | D-pad Down / Left Stick Down |
| Left | D-pad Left / Left Stick Left |
| Right | D-pad Right / Left Stick Right |
| Fire | A / Cross (bottom face button) |

#### Shared Gamepad Presets

For two players sharing one gamepad, offer these quick-setup presets:

| Preset | Player A Controls | Player B Controls |
|--------|-------------------|-------------------|
| **D-pad + Buttons** | D-pad (directions) + L1 (fire) | Face buttons Y/X/A/B (up/left/down/right) + R1 (fire) |
| **Split Stick** | Left stick (directions) + L1 (fire) | Right stick (directions) + R1 (fire) |

Presets populate individual bindings — players can further customize after applying a preset.

#### Multiple Keyboard Support

**MVP**: All keyboards are merged into one input stream (Godot default). Key bindings are unique per player, so simultaneous keyboard use works — each key is routed to whichever player has it bound. This is sufficient for local play.

**Post-V1**: Investigate Windows `RawInput` API via GDExtension to distinguish individual keyboards by device ID. This would allow two players to both bind "W" on different physical keyboards. The `Binding.device_index` field is already present in the data model to support this.

#### Input Routing

1. Raw input event arrives (key press, gamepad button)
2. Input System checks which player (if any) has this key/button bound
3. If matched, produce a game action for that player
4. Pass the action to Turn Director: `(player_id, action_type)`
5. If no player matches, ignore the input (or route to UI if in menu context)

#### Conflict Detection

During configuration, the Input System validates:
- No two players share the same binding (same device_type + device_index + key_or_button + axis_direction)
- No single binding is mapped to multiple actions for the same player
- Intentional sharing (e.g., shared gamepad presets) is not flagged — only unintentional duplicates

Conflicts are flagged as warnings in the Menu System — they don't block saving but show a clear indicator. This allows creative setups while still catching accidental overlaps.

#### Gamepad Handling

- Poll connected gamepads via Godot's `Input.get_connected_joypads()`
- Handle connect/disconnect events gracefully (show notification, pause if active player disconnects)
- Analog stick inputs use a dead zone threshold (default 0.5) to convert to digital direction

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Menu Mode** | Application start / match ends | Match starts | Routes input to UI navigation (Menu System) |
| **Game Mode** | Match starts | Match ends / pause | Routes input to game actions (Turn Director) |
| **Paused** | Pause triggered | Unpause | Input routed to pause menu only |
| **Rebinding** | Player enters rebind mode in settings | Key/button pressed (captured as new binding) | Next input is captured as the new binding, not treated as an action |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Game Config** | This reads | Player list (which players are human), per-player input config |
| **Turn Director** | Turn Director reads from this | Receives `(player_id, action_type)` when a human player acts |
| **Menu System** | Bidirectional | Input System routes UI navigation in menu mode; Menu System writes binding changes back to config |
| **Settings Manager** | Settings Manager persists | Input bindings saved/loaded as part of player config |

## Formulas

### Analog Stick Dead Zone

```
is_direction_pressed(axis_value: float, dead_zone: float = 0.5) -> bool:
    return abs(axis_value) > dead_zone
```

### Direction Queuing (Fire-Required Mode)

```
on_fire_pressed(player_id):
    if queued_direction[player_id] != null:
        emit_action(player_id, SWIPE + queued_direction[player_id])
        queued_direction[player_id] = null
    else:
        emit_action(player_id, FIRE)

on_direction_pressed(player_id, direction):
    if input_mode == DIRECT:
        emit_action(player_id, SWIPE + direction)
    else:  // FIRE_REQUIRED
        queued_direction[player_id] = direction
        // Direction expires after a short window (e.g., 0.3s) if fire isn't pressed
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Two players press fire on the same frame | Both actions queued; Turn Director resolves which arrived first (or uses frame-order tiebreak) | Input System doesn't resolve races — Turn Director does |
| Gamepad disconnected mid-match | Show notification, player treated as inactive until reconnected or match paused | Graceful degradation |
| Player holds direction then presses fire (fire-required mode) | Direction is queued, fire triggers swipe in that direction | Expected UX flow |
| Player presses fire without direction (fire-required mode) | Tap action (FIRE) | No direction = no chain |
| Direction queued but fire not pressed within 0.3s | Direction expires, cleared from queue | Prevents stale direction from triggering on a later fire press |
| Same binding on two players (unintentional conflict) | Warning shown in config UI; during gameplay, BOTH players receive the action | Conflict detection warns but doesn't block — player's choice |
| Two players sharing one gamepad (intentional) | No conflict warning — shared gamepad presets mark bindings as intentionally shared | Different buttons on same device is valid sharing, not a conflict |
| Player mixes keyboard and gamepad bindings | Fully supported — each action has its own independent Binding | Core design principle: no device-per-player constraint |
| Gamepad disconnected while two players share it | Both players affected — show notification for both, pause recommended | Shared device = shared risk |
| CPU player | No input routing — CPU Controller generates actions directly to Turn Director | Input System only handles human players |
| All players are CPU | Input System enters idle state — no human input to process | Valid spectator mode |
| Rebind mode: player presses Escape | Cancel rebind, keep previous binding | Standard UX convention |
| Rebind mode: player presses a key already bound to another player | Accept the binding, show conflict warning | Player can fix conflicts later |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Game Config** | This depends on Game Config | Reads player list, input device type, bindings (hard) |
| **Turn Director** | Turn Director depends on this | Receives human player actions (hard) |
| **Menu System** | Bidirectional | Input routes to UI in menu mode; Menu writes binding changes (soft — system works with defaults if no menu) |
| **Settings Manager** | Settings Manager persists this | Saves/loads binding configurations (soft) |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `dead_zone` | 0.5 | 0.1–0.9 | Requires more deliberate stick movement — fewer accidental directions | More sensitive — easier to trigger directions but more false positives |
| `direction_queue_timeout` | 0.3s | 0.1–1.0s | More time to press fire after direction — more forgiving | Requires faster execution — rewards precision |

## Acceptance Criteria

- [ ] All 4 default keyboard player bindings produce correct actions
- [ ] Gamepad d-pad and analog stick both produce direction actions
- [ ] Fire-required mode: direction + fire = swipe, fire alone = tap
- [ ] Direct mode: direction alone = swipe, fire alone = tap
- [ ] Direction queue expires after timeout (default 0.3s)
- [ ] Conflict detection flags duplicate key bindings between players
- [ ] Gamepad connect/disconnect handled gracefully with notification
- [ ] Rebind mode captures next input as new binding
- [ ] Rebind cancelled with Escape, preserving previous binding
- [ ] CPU players generate no input events through Input System
- [ ] Input routing switches between Menu Mode and Game Mode correctly
- [ ] Analog dead zone prevents accidental direction triggers
- [ ] No input latency beyond one physics frame (target: ≤16.6ms at 60fps)
- [ ] 8 simultaneous players with mixed keyboard/gamepad configurations work correctly
- [ ] Single player can mix keyboard and gamepad bindings (e.g., WASD + gamepad fire)
- [ ] Two players sharing one gamepad with different buttons both receive correct actions
- [ ] Shared gamepad presets correctly populate individual bindings for both players
- [ ] Binding data model stores device_type + device_index + key_or_button per action
