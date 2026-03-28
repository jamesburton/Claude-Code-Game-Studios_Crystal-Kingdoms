# Sprint 2 — Polish, CPU Play, and Vertical Slice

## Sprint Goal
Add CPU opponents to the playable game, implement castle sprites, add configurable player setup, and deliver a vertical slice with single-player vs CPU gameplay.

## Velocity from Sprint 1
Sprint 1 delivered all 10 MVP systems + visual layer in a single session (13 tasks completed). The core logic is solid with 177 passing tests. Sprint 2 can be ambitious.

## Capacity
- Total sessions: 3 (estimated)
- Buffer (20%): 1 session reserved
- Available: 2 focused sessions

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S2-01 | Wire CPU controllers into GameScene | CPU Controller | S | None | GameScene supports configurable human/CPU player setup; CPU players act autonomously against humans |
| S2-02 | Use castle sprites instead of ColorRects | Board Renderer | S | None | 64x64 castle PNGs from `images/` rendered per player color; empty = neutral sprite; cursor = overlay sprite |
| S2-03 | Show contagion as colored gem sprites | Board Renderer | S | S2-02 | 6x6 gem PNGs positioned around castle cells; contagion level shown visually |
| S2-04 | Add chain trail visualization | Board Renderer | S | None | Line2D or highlight showing the chain path during traversal; fades after chain ends |
| S2-05 | Pre-match configuration screen | Menu System | M | None | Simple screen to set: grid size (6-12), player count (2-8), human/CPU per player, difficulty, speed preset; start match button |
| S2-06 | Match-end rematch/change settings flow | HUD | S | S2-05 | End screen buttons: Rematch (same config), Change Settings (back to config screen), Quit |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S2-07 | Score curve preview in config screen | Menu System | S | S2-05 | Show effective values for n=1..5 alongside curve/multiplier selectors |
| S2-08 | Compact HUD for 5+ players | HUD | S | None | Player score cards use compact layout when >4 players; all 8 colors visible |
| S2-09 | Spectator mode (all CPU) | CPU Controller | S | S2-01 | All players set to CPU; match runs autonomously; user can watch |
| S2-10 | Add CPU difficulty profiles to config screen | Menu System | S | S2-05 | Per-CPU player difficulty dropdown (Easy/Medium/Hard) |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S2-11 | Settings persistence via ConfigFile | Settings Manager | S | S2-05 | Last-used config saved to user://settings.cfg; loaded on next launch |
| S2-12 | Scene transitions (menu → match → results) | Scene Management | S | S2-05, S2-06 | Proper Godot scene changes instead of in-scene swapping |
| S2-13 | Sound effects (capture, contagion, chain, cursor) | Audio System | M | None | Basic SFX for core events; volume slider in config |

## Carryover from Sprint 1

| Task | Reason | New Estimate |
|------|--------|-------------|
| S1-11: GUT testing framework | Deprioritized — custom runner works well | Deferred to Sprint 3 |
| S1-14: Port prototype tests to GUT | Depends on S1-11 | Deferred to Sprint 3 |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Sprite scaling looks bad at large grid sizes | Medium | Low | Test at 12x12; may need higher-res sprites or shader-based scaling |
| Menu system scope creep (too many options) | Medium | Medium | Start with essential options only; advanced scoring config in Sprint 3 |
| CPU timing feels unfair vs human at certain speed presets | Low | Medium | Playtest all 3 difficulties × 4 speed presets; tune reaction times |

## Dependencies on External Factors
- Castle/gem sprite files already present in `images/`
- No external libraries needed

## Definition of Done for this Sprint
- [ ] All Must Have tasks (S2-01 through S2-06) completed
- [ ] Game launches to config screen, player configures match, plays vs CPU
- [ ] Castle sprites render correctly at all grid sizes 6-12
- [ ] Match end → rematch or change settings works
- [ ] 177+ tests still passing (no regressions)
- [ ] Committed to main branch
