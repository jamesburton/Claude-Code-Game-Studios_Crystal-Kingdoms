# Sprint 7 — LAN Multiplayer & Replay Viewer

## Sprint Goal
Enable real-time multiplayer over local network (WebSocket) and complete the replay viewer for reviewing past matches.

## Context
With v1.5.0 delivering a polished single-device experience, Sprint 7 focuses on the two most-requested features: network play and replays. This is the most architecturally complex sprint — networking requires careful state synchronization.

## Velocity
Sprints 1-6 delivered 70+ features in 2 sessions. Networking is higher complexity per task.

## Capacity
- Total sessions: 3 (estimated — networking takes longer)
- Buffer (20%): 1 session
- Available: 2 focused sessions

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S7-01 | Replay list screen | UI | S | None | List saved replays (timestamp, grid, players, scores); select to load; delete |
| S7-02 | Replay playback viewer | UI | M | S7-01 | Board reconstructed from replay; step through turns; show evolving state |
| S7-03 | Replay playback controls | UI | S | S7-02 | Play/Pause/Step buttons; speed slider (0.5x-4x) |
| S7-04 | WebSocket game server (in-process) | Networking | L | None | GDScript WebSocket server in host process; manages rooms, cursor spawning, action validation, event broadcast |
| S7-05 | WebSocket client connection | Networking | M | S7-04 | Client connects to host IP:port; receives cursor/events; sends actions |
| S7-06 | Network lobby UI | UI | M | S7-04 | Host: create room, show IP/port; Client: enter IP, connect; Player list with ready; Host starts match |
| S7-07 | Server-authoritative game loop | Networking | L | S7-04 | Server runs RulesEngine; validates actions; broadcasts events; clients render from events |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S7-08 | LAN discovery (UDP broadcast) | Networking | S | S7-04 | Host broadcasts on UDP 19736; clients show "LAN Games" list |
| S7-09 | Network ping display | HUD | S | S7-05 | Show round-trip latency per player during online match |
| S7-10 | Disconnect handling | Networking | S | S7-05 | CPU takes over for disconnected player after 10s; reconnection possible |
| S7-11 | Keyboard rebinding UI | Input System | M | None | Click-to-rebind per player slot; capture next key; validate no conflicts |
| S7-12 | Shared gamepad presets | Input System | S | None | "D-pad + Buttons" and "Split Stick" two-on-one-gamepad presets |
| S7-13 | Menu transitions (fade) | UI | S | None | 0.3s fade between screens (intro→menu→options→game→results) |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S7-14 | Room codes (internet play) | Networking | M | S7-04 | 6-char codes via relay server; no port forwarding needed |
| S7-15 | Spectator mode (online) | Networking | S | S7-05 | Join as observer; receive events; no input |
| S7-16 | Quick emotes during match | UI | S | S7-05 | 4 emote buttons sent to all players (thumbs up, wow, gg, oops) |
| S7-17 | Match statistics history | Persistence | S | None | Save per-match stats; show win/loss/averages over time |
| S7-18 | High contrast accessibility mode | UI | S | None | Toggle for high-contrast colors, larger borders, bigger text |
| S7-19 | Victory celebration animation | UI | S | None | Particles + sound burst when winner shown |
| S7-20 | Menu hover/click SFX | Audio | S | None | Subtle sounds on button hover and press |

## Carryover

| Task | Source | New Estimate |
|------|--------|-------------|
| Replay viewer | Sprint 5 (S5-05/06) | S+M (now S7-01/02/03) |
| LAN multiplayer | Original Sprint 6 plan | L+M+M+L (S7-04/05/06/07) |
| Keyboard rebinding | Sprint 5 (S5-15) | M (S7-11) |
| Shared gamepad | Sprint 5 (S5-16) | S (S7-12) |
| Menu transitions | Sprint 6 (S6-11) | S (S7-13) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| WebSocket server in GDScript: threading/performance | Medium | High | Use Godot's WebSocketMultiplayerPeer; test with 4+ clients; fall back to ENet if needed |
| Cursor claim racing over network needs careful timing | High | High | Server-authoritative: server timestamps actions; earliest valid wins; clients predict locally |
| Network play feels laggy (>100ms) | Medium | High | Minimize round trips: server broadcasts events, clients render immediately; use delta compression |
| Replay format changes break old replays | Low | Low | Version field in JSON; validate on load; skip incompatible |

## Architecture Reference
- [Online Multiplayer GDD](../../design/gdd/online-multiplayer.md) — full design for Phases 1-4
- Phase 1 (LAN) is this sprint's scope

## Dependencies on External Factors
- Network testing needs 2+ game instances (localhost or LAN devices)
- Internet play (S7-14) needs a relay/signaling server

## Definition of Done for this Sprint
- [ ] All Must Have tasks (S7-01 through S7-07) completed
- [ ] Replays saveable, listable, loadable, and playable with speed control
- [ ] Two game instances connect and play a complete match over localhost/LAN
- [ ] Server-authoritative: server validates all actions and owns game state
- [ ] Network play feels responsive (<100ms perceived latency on LAN)
- [ ] 200+ tests passing (new: replay load/save, network message serialization)
- [ ] Tagged as v2.0.0
