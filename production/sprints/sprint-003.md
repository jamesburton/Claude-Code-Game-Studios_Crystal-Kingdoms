# Sprint 3 — Game Feel, Persistence, and Polish

## Sprint Goal
Elevate Crystal Kingdoms from functional to polished: add sound effects, settings persistence, visual polish (gem contagion display, chain trails), advanced config options, and gamepad support.

## Velocity
Sprint 1+2 delivered the full MVP + CI/CD + web deployment across 2 sessions. Sprint 3 focuses on feel and completeness rather than new systems.

## Capacity
- Total sessions: 2-3 (estimated)
- Buffer (20%): 1 session
- Available: 2 focused sessions

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S3-01 | Settings persistence via ConfigFile | Settings Manager | S | None | Last-used config saved to user://settings.cfg on match start; loaded on launch; validated on load |
| S3-02 | Contagion gem sprites around castles | Board Renderer | M | None | Colored 24x24 gem sprites positioned around castle cells; show contagion level visually per threatening player |
| S3-03 | Chain trail Line2D visualization | Board Renderer | S | None | Line2D drawn between chain cells during traversal; fades after chain ends |
| S3-04 | Gamepad input support | Input System | M | None | D-pad/stick for directions, face button for fire; per-player gamepad binding; works alongside keyboard |
| S3-05 | Score curve preview in config | Config Screen | S | None | Show effective values for n=1..5 next to curve/multiplier selectors for adjacency/contagion/capture |
| S3-06 | Sound effects (capture, contagion, chain, cursor) | Audio | M | None | At least 4 distinct SFX; volume control in config |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S3-07 | Scoring mode selector in config | Config Screen | S | None | BASIC vs ONLY_CASTLES toggle with explanation text |
| S3-08 | Wrap-around toggle in config | Config Screen | S | None | Toggle for wrap_around; default on |
| S3-09 | Winning score option in config | Config Screen | S | None | Slider for winning_score (0=disabled, 10-500); match ends when reached |
| S3-10 | Post-V1 options greyed out | Config Screen | S | None | Danger cells, bonus cells, boosts shown as "Coming Soon" labels |
| S3-11 | Match statistics tracking | Match Flow | S | None | Track total_captures, max_castles_held, longest_chain per player; show in end screen |
| S3-12 | Improved end screen with stats | HUD | S | S3-11 | Show per-player stats: captures, max castles, longest chain, actions taken |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S3-13 | Lone castle scores zero toggle in config | Config Screen | S | None | Checkbox in advanced scoring section |
| S3-14 | Cursor select captured toggle | Config Screen | S | None | Checkbox; enables cursor on owned cells when all cells owned |
| S3-15 | Capture threshold explanation tooltip | Config Screen | S | None | Hover/info text explaining what threshold means |
| S3-16 | Animated cursor spawn (scale-in) | Board Renderer | S | None | Cursor scales from 0 to full size over 0.15s on spawn |
| S3-17 | Screen shake on contagion capture | Board Renderer | S | None | Subtle camera shake (2-3px, 0.2s) on capture_contagion events |

## Carryover from Sprint 2

| Task | Reason | New Estimate |
|------|--------|-------------|
| S2-07 Score curve preview | Config screen scope | S (now S3-05) |
| S2-11 Settings persistence | Not critical for v1.0 | S (now S3-01) |
| S2-13 Sound effects | Needs audio assets | M (now S3-06) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Generating/finding suitable SFX | Medium | Medium | Use procedural audio (Godot AudioStreamGenerator) or free CC0 sound packs |
| Gamepad detection across platforms | Low | Medium | Test with Xbox/PS controllers; Godot's Input system handles most gamepads |
| Config screen getting too crowded | Medium | Low | Add collapsible "Advanced" section for scoring curves and toggles |

## Dependencies on External Factors
- Sound effect assets (generate procedurally or source CC0 packs)
- Gamepad for testing (keyboard fallback always works)

## Definition of Done for this Sprint
- [ ] All Must Have tasks (S3-01 through S3-06) completed
- [ ] Settings persist across sessions
- [ ] Contagion visually readable with gem sprites
- [ ] Gamepad input works for at least P1
- [ ] At least 4 sound effects playing on game events
- [ ] 190+ tests passing
- [ ] Tagged as v1.1.0, deployed to GitHub Pages
- [ ] Committed to main branch
