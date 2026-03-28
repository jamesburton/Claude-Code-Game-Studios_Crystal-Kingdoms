# Sprint 6 — Replay Viewer, Online Foundation, Quality

## Sprint Goal
Complete the replay viewer for match review, lay the networking foundation for online multiplayer (LAN first), and address accumulated quality/UX debt.

## Velocity
Sprints 1-5 delivered 60+ features across 2 sessions with 200 tests. Sprint 6 tackles deeper systems (networking, replay UI) that require more careful architecture.

## Capacity
- Total sessions: 2-3 (estimated)
- Buffer (20%): 1 session
- Available: 2 focused sessions

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S6-01 | Replay list screen | UI | S | None | List saved replays with timestamp, grid size, player count, scores; select to view; delete option |
| S6-02 | Replay playback viewer | UI | M | S6-01 | Load replay, recreate board, step through turn_history with play/pause/step controls; show board state evolving |
| S6-03 | Replay playback speed control | UI | S | S6-02 | Slider: 0.5x, 1x, 2x, 4x playback speed |
| S6-04 | LAN WebSocket server (in-process) | Networking | M | None | GDScript WebSocket server runs in host's game process; broadcasts cursor spawns, accepts actions, sends authoritative events |
| S6-05 | LAN client connection | Networking | M | S6-04 | Client connects to host via IP:port; receives cursor/events; sends actions |
| S6-06 | LAN game lobby | UI | S | S6-04 | Host creates room, shows IP; clients join by entering IP; player list + ready status; host starts match |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S6-07 | LAN discovery (UDP broadcast) | Networking | S | S6-04 | Host broadcasts presence on port 19736; clients show "LAN Games" list |
| S6-08 | Network latency display | HUD | S | S6-05 | Show ping (ms) per player during online match |
| S6-09 | Keyboard rebinding UI | Input System | M | None | Click-to-rebind per player slot in config; capture next key press |
| S6-10 | Custom board editor | UI | M | None | Click cells to toggle blocked/unblocked; save/load as named presets |
| S6-11 | Match statistics history | Persistence | S | None | Save per-match stats to user://stats.json; show win/loss record per config |
| S6-12 | Shared gamepad presets | Input System | S | None | "D-pad + Buttons" and "Split Stick" 2-player-1-gamepad presets |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S6-13 | Room codes for internet play | Networking | M | S6-04 | 6-char codes instead of IP; requires relay server or STUN |
| S6-14 | Spectator mode for online | Networking | S | S6-05 | Join as observer, receive events, no input |
| S6-15 | Chat/emotes during match | UI | S | S6-05 | Quick emote buttons (thumbs up, wow, gg) sent to all players |
| S6-16 | Music system | Audio | M | None | Background music tracks; crossfade between menu/match; volume separate from SFX |
| S6-17 | Accessibility: high contrast mode | UI | S | None | Toggle for high-contrast colors, larger text, thicker borders |

## Carryover from Sprint 5

| Task | Reason | New Estimate |
|------|--------|-------------|
| S5-05 Replay playback viewer | UI not built yet | M (now S6-02) |
| S5-06 Replay list screen | UI deferred | S (now S6-01) |
| S5-12 Online leaderboard | Superseded by LAN multiplayer focus | Deferred |
| S5-15 Keyboard rebinding | S (now S6-09) |
| S5-16 Shared gamepad presets | S (now S6-12) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| WebSocket in GDScript may have threading issues | Medium | High | Use Godot's built-in WebSocketMultiplayerPeer; test with 2+ clients locally |
| Cursor claim racing over network needs careful timing | High | High | Server-authoritative: server decides claim winner by arrival order; client shows prediction |
| Replay files from different versions may be incompatible | Low | Medium | Version field in replay JSON; validate on load |
| LAN discovery blocked by firewall | Medium | Medium | Fall back to manual IP entry; document firewall requirements |

## Dependencies on External Factors
- Network testing requires 2+ devices on same LAN (or localhost with multiple instances)
- Internet play (S6-13) needs a relay/signaling server

## Definition of Done for this Sprint
- [ ] All Must Have tasks (S6-01 through S6-06) completed
- [ ] Replays can be saved, listed, loaded, and played back
- [ ] Two game instances can play a match over LAN
- [ ] Network play feels responsive (< 100ms perceived latency)
- [ ] 200+ tests passing
- [ ] Tagged as v1.5.0, deployed to GitHub Pages
