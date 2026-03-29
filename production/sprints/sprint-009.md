# Sprint 9 — Internet Play, Social Features, and Content

## Sprint Goal
Enable internet multiplayer via room codes (relay server or WebRTC signaling), add social features (spectator, emotes), and expand content with match history, accessibility, and remaining polish.

## Context
Phase 1 LAN multiplayer is complete (Sprint 8). Sprint 9 extends to internet play (Phase 2 of the online-multiplayer GDD) and fills remaining feature gaps.

## Capacity
- Total sessions: 3 (estimated — relay server is new infrastructure)
- Buffer (20%): 1 session
- Available: 2 focused sessions

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S9-01 | Relay/signaling server | Networking | L | None | Standalone Node.js or Go WebSocket relay; rooms identified by 6-char codes; forwards messages between host and clients |
| S9-02 | Room codes in lobby UI | UI | S | S9-01 | Host creates room → gets code; Client enters code → connects through relay; no port forwarding needed |
| S9-03 | Deploy relay to cloud | DevOps | S | S9-01 | Deploy to Fly.io or Railway; web version connects to public relay by default |
| S9-04 | Spectator mode | Networking | S | None | Join as observer (no player slot); receive cursor + events; no input; spectator count shown |
| S9-05 | Match history / statistics | Persistence | S | None | Save per-match stats to user://stats.json; show win/loss record, favorite config, average score |
| S9-06 | High contrast accessibility | UI | S | None | Toggle: high-contrast colors, thicker borders, larger contagion text |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S9-07 | Quick emotes | UI/Net | S | None | 4 emote buttons during match (GG, Wow, Nice, Oops); displayed as floating text on all clients |
| S9-08 | Custom board editor | UI | M | None | Click cells to toggle blocked/neutral/danger/bonus; save/load named board presets |
| S9-09 | Shared gamepad presets | Input | S | None | "D-pad + Buttons" and "Split Stick" presets for 2 players on 1 gamepad |
| S9-10 | Music track variety | Audio | S | None | 3+ procedural music variations; random selection per match |
| S9-11 | Keybindings in options flow | UI | S | None | Add "Keybindings" button to config/options screen; link to KeybindScreen |
| S9-12 | Menu SFX integration | Audio | S | None | Play hover/click sounds on all menu buttons |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S9-13 | Friend list / recent players | Networking | M | S9-01 | Remember room codes joined; show recent games list |
| S9-14 | Online leaderboard (web) | Web | M | S9-03 | POST scores to relay server; show top 10 on web version |
| S9-15 | Tournaments / bracket mode | UI | L | S9-01 | Multi-round elimination brackets for 4-8 players |
| S9-16 | Mobile touch controls | Input | M | None | Touch-friendly UI + swipe input for mobile web |
| S9-17 | Theme selector | UI | S | None | Light/dark/crystal themes for menu and gameplay |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Relay server hosting costs | Low | Medium | Use free tiers (Fly.io 3 VMs free, Railway $5/mo) |
| WebSocket relay adds latency vs direct LAN | Medium | Medium | Keep relay lightweight (just forward messages); measure RTT |
| Room code collisions | Low | Low | 6 chars = 2B+ combinations; check for uniqueness on creation |
| Spectator mode: bandwidth for many spectators | Low | Medium | Rate-limit event broadcast; aggregate events in batches |

## Dependencies on External Factors
- Cloud hosting account for relay server (Fly.io, Railway, or Cloudflare)
- Domain/URL for relay endpoint (or use IP)

## Definition of Done
- [ ] Two players on different networks play via room code (no port forwarding)
- [ ] Spectator can watch a live match
- [ ] Match history shows win/loss stats
- [ ] High contrast mode toggleable
- [ ] 221+ tests passing
- [ ] Tagged as v3.0.0
