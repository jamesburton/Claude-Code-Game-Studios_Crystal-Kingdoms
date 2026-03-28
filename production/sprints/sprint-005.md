# Sprint 5 — Board Variants, Replay, and Post-V1 Foundation

## Sprint Goal
Implement board shape variants (blocked cells creating non-rectangular layouts), a replay system for reviewing past matches, and lay the groundwork for post-V1 features (danger/bonus cells).

## Velocity
Sprints 1-4 delivered the full game + polish in 2 sessions (40+ tasks). Sprint 5 tackles the more ambitious features deferred from earlier sprints.

## Capacity
- Total sessions: 2-3 (estimated)
- Buffer (20%): 1 session
- Available: 2 focused sessions

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S5-01 | Blocked cells in BoardState | Board State | S | None | Cells can be marked as blocked (impassable); blocked cells don't accept captures, contagion, or cursor placement; chains skip/stop at blocked cells |
| S5-02 | Board shape presets | Config Screen | M | S5-01 | Dropdown: Rectangle (default), Diamond, Hourglass, Cross, Ring; each preset marks edge/corner cells as blocked |
| S5-03 | Blocked cell rendering | Board Renderer | S | S5-01 | Blocked cells render as dark/hatched, distinct from empty; no interaction indicators |
| S5-04 | Replay recording | Match Flow | S | None | Save complete EventLog + config to user://replays/ as JSON after each match |
| S5-05 | Replay playback viewer | UI | M | S5-04 | Load replay file, step through events with play/pause/speed controls, show board state at each step |
| S5-06 | Replay list screen | UI | S | S5-04 | List saved replays with date, player count, scores; select to view |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S5-07 | Pre-placed castles option | Config Screen | S | S5-01 | Toggle to start with random cells pre-owned (1-2 per player); asymmetric but fair |
| S5-08 | Custom board editor (simple) | UI | M | S5-01 | Click cells to toggle blocked/unblocked; save as preset |
| S5-09 | Danger cells (reduced score) | Board State | S | S5-01 | Some cells give 50% scoring; marked with warning color |
| S5-10 | Bonus cells (double score) | Board State | S | S5-01 | Some cells give 200% scoring; marked with gold color |
| S5-11 | Danger/bonus cell config | Config Screen | S | S5-09, S5-10 | Sliders for danger_cell_count and bonus_cell_count; randomly placed at match start |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S5-12 | Online leaderboard (web) | Web | L | None | POST scores to GitHub Gist or simple API; show top 10 on web version |
| S5-13 | Match statistics history | Persistence | S | None | Save per-match stats; show historical win/loss/averages |
| S5-14 | CPU personality names | CPU Controller | S | None | Each CPU difficulty has a name ("Novice", "Strategist", "Champion") shown in setup |
| S5-15 | Keyboard rebinding UI | Input System | M | None | Click-to-rebind in config screen per player slot |
| S5-16 | Shared gamepad presets | Input System | S | None | "D-pad + Buttons" and "Split Stick" presets for 2 players on 1 gamepad |

## Carryover from Sprint 4

| Task | Reason | New Estimate |
|------|--------|-------------|
| S4-13 Board shapes | Needs blocked cell foundation first | M (now S5-02) |
| S4-14 Pre-placed castles | Depends on blocked cells | S (now S5-07) |
| S4-15 Replay system | Medium effort | M (now S5-04/05/06) |
| S4-16 Online leaderboard | Needs backend | L (now S5-12) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Blocked cells break chain/navigation assumptions | Medium | High | Thorough testing: chains through/around blocked cells, cursor spawn avoids blocked |
| Board shapes feel gimmicky without balance testing | Medium | Medium | Start with 3 shapes; playtest CPU vs CPU on each to verify no degenerate positions |
| Replay files grow large on long matches | Low | Low | Compress EventLog (store only actions + config, replay by re-running Rules Engine) |

## Dependencies on External Factors
- Online leaderboard needs a hosting solution (GitHub Gist, Supabase, or simple REST API)

## Definition of Done for this Sprint
- [ ] All Must Have tasks (S5-01 through S5-06) completed
- [ ] Board shapes playable and balanced (tested with CPU matches)
- [ ] At least one replay can be saved, loaded, and viewed
- [ ] Blocked cells tested with all chain/scoring scenarios
- [ ] 190+ tests passing (new tests for blocked cells)
- [ ] Tagged as v1.4.0, deployed to GitHub Pages
