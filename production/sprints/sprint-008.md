# Sprint 8 — LAN Multiplayer Completion & Replay Viewer

## Sprint Goal
Complete functional LAN multiplayer (two+ devices playing a live match over WebSocket) and deliver the replay viewer UI for reviewing saved matches.

## Context
Sprint 7 delivered the networking foundation (server, client, protocol, lobby UI). Sprint 8 wires it into actual playable networked matches and adds replay playback.

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S8-01 | Network match integration | Networking | M | None | Host starts match from lobby; server ticks match_flow; broadcasts cursor/events; all clients see same board state |
| S8-02 | Client-side board rendering from server events | UI/Net | M | S8-01 | Client creates BoardState + BoardRenderer; applies events received from server; cursor appears/disappears from server messages |
| S8-03 | Client action submission | Networking | S | S8-01 | Client sends direction/tap to server via WebSocket; server validates and resolves; result broadcast to all |
| S8-04 | Host plays as player 0 | Networking | S | S8-01 | Host's local input goes to server match_flow; host sees same board as clients |
| S8-05 | Network match end + return to lobby | UI/Net | S | S8-01 | Server broadcasts match_end; all clients show results; return to lobby for rematch |
| S8-06 | Replay list screen | UI | S | None | List user://replays/ files with timestamp, grid, scores; select to load |
| S8-07 | Replay playback viewer | UI | M | S8-06 | Recreate board from replay config; step through turns applying actions to rules engine; show evolving board |
| S8-08 | Replay playback controls | UI | S | S8-07 | Play/Pause/Step-forward buttons; speed slider (0.5x, 1x, 2x, 4x) |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S8-09 | LAN discovery (UDP broadcast) | Networking | S | S8-01 | Host broadcasts on UDP 19736; clients show discovered servers in lobby |
| S8-10 | Network ping display | HUD | S | S8-02 | Show round-trip latency (ms) during online match |
| S8-11 | Disconnect/reconnect handling | Networking | S | S8-01 | CPU takes over for disconnected player after 10s; player can rejoin |
| S8-12 | Network match config sync | Networking | S | S8-01 | Host sets config in lobby; config sent to all clients on match start |
| S8-13 | Replay from main menu | UI | S | S8-06 | "Replays" button in main menu between Online and Options |
| S8-14 | Keyboard rebinding UI | Input | M | None | Click-to-rebind per player; capture next key; validate conflicts |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S8-15 | Room codes (internet relay) | Networking | L | S8-01 | 6-char code via relay server; no port forwarding needed |
| S8-16 | Spectator mode (online) | Networking | S | S8-02 | Join as observer; see events; no input |
| S8-17 | Quick emotes | UI/Net | S | S8-03 | 4 emote buttons; sent to all players |
| S8-18 | Match statistics history | Persistence | S | None | Save per-match stats; show win/loss/averages |
| S8-19 | High contrast accessibility | UI | S | None | Toggle for high-contrast colors, larger borders |
| S8-20 | Shared gamepad presets | Input | S | None | 2-player-1-gamepad presets |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| WebSocket packet ordering on congested LAN | Low | Medium | JSON messages are small; WebSocket guarantees ordering |
| Client board state drift from server | Medium | High | Server is authoritative; clients rebuild from events, not predict |
| Replay file format changes between versions | Low | Low | Version field validates compatibility |
| Two instances on same machine: port conflict | Medium | Low | Use different ports or allow port config in lobby |

## Dependencies on External Factors
- LAN testing: 2+ devices or 2 game instances on localhost
- Internet relay (S8-15): needs external server hosting

## Definition of Done
- [ ] Two game instances play a complete match over localhost WebSocket
- [ ] Host and clients see synchronized board state throughout
- [ ] Match end results shown on all clients
- [ ] Replays listable, loadable, and playable with speed control
- [ ] 212+ tests passing
- [ ] Tagged as v2.1.0
