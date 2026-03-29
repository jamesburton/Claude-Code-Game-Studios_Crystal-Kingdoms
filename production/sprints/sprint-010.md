# Sprint 10 — Content, QoL, and Release Hardening

## Sprint Goal
Complete remaining feature gaps, add content variety, harden for public release quality, and prepare for wider distribution.

## Context
With v3.0.0 delivering internet multiplayer, Sprint 10 focuses on filling feature gaps, improving QoL, and hardening everything for a confident public release.

## Capacity
- Total sessions: 2 (estimated)
- Buffer (20%): 1 session
- Available: 1-2 focused sessions

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S10-01 | Custom board editor | UI | M | None | Click cells to toggle: empty/blocked/neutral/danger/bonus/reinforced/fortified; save/load named presets to user:// |
| S10-02 | Shared gamepad presets | Input | S | None | Config screen: "2 Players 1 Gamepad" preset button; P1=dpad+L1, P2=face+R1 |
| S10-03 | Keybindings in options flow | UI | S | None | "Keybindings" button in config screen links to KeybindScreen with back navigation |
| S10-04 | Menu SFX on all buttons | Audio | S | None | All Button nodes play hover/click sounds from SoundManager |
| S10-05 | Deploy relay to Fly.io | DevOps | S | None | `flyctl deploy` from server/; public URL wired into lobby default relay address |
| S10-06 | Relay connection in lobby | Networking | S | S10-05 | "Online" mode connects through relay; room codes work end-to-end |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S10-07 | Emote display in game | UI | S | None | 4 emote buttons during match; show floating emote text on board for all players |
| S10-08 | Mobile touch controls | Input | M | None | Touch-friendly buttons for web mobile; swipe gestures for directions |
| S10-09 | Theme selector | UI | S | None | 3 themes: Dark (default), Light, Crystal; affects menu + gameplay colors |
| S10-10 | Online leaderboard | Web | M | S10-05 | POST scores to relay; show top 10 on web version main menu |
| S10-11 | Comprehensive test expansion | Testing | M | None | Add tests for: network message validation, board shapes + special cells combos, replay round-trip, config persistence; target 250+ tests |
| S10-12 | Performance profiling | QA | S | None | Profile at 12x12 grid with 8 players; verify <16.6ms frame time; document results |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S10-13 | Tournament / bracket mode | UI | L | None | 4-8 player elimination brackets; automated round progression |
| S10-14 | Friend list / recent players | Networking | M | S10-05 | Remember joined room codes; show recent games |
| S10-15 | Animated gem decorations | UI | S | None | Small gems float in menu borders |
| S10-16 | More board shapes | Board State | S | None | Triangle, Spiral, Maze presets |
| S10-17 | Localization framework | Core | M | None | String extraction + translation table; support EN + 1 other language |

## Carryover from Sprint 9

| Task | Source | New Estimate |
|------|--------|-------------|
| S9-08 Custom board editor | Deferred | M (now S10-01) |
| S9-09 Shared gamepad | Deferred | S (now S10-02) |
| S9-11 Keybindings in options | Deferred | S (now S10-03) |
| S9-12 Menu SFX | Deferred | S (now S10-04) |
| S9-03 Deploy relay | Incomplete | S (now S10-05) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Fly.io free tier limits | Low | Medium | Free tier: 3 VMs, 256MB; relay is very lightweight |
| Mobile touch may not work well for fast cursor racing | Medium | Medium | Add configurable touch-hold delay; test on actual mobile |
| Test expansion reveals bugs | Medium | Positive | Better to find them now than after wider release |

## Dependencies on External Factors
- Fly.io account for relay deployment
- Mobile device for touch control testing

## Definition of Done
- [ ] All Must Have tasks (S10-01 through S10-06) completed
- [ ] Custom board editor functional with save/load
- [ ] Relay server deployed and accessible from web version
- [ ] All menu buttons play SFX
- [ ] 221+ tests passing
- [ ] Tagged as v3.1.0
