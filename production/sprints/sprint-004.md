# Sprint 4 — Juice, Accessibility, and Content

## Sprint Goal
Add visual juice (animations, particles, screen effects), accessibility features, tutorial/onboarding, and prepare for the post-V1 features roadmap.

## Velocity
Sprints 1-3 delivered 10 MVP systems + visual layer + polish + CI/CD across 2 sessions. Project is well ahead of typical schedule.

## Capacity
- Total sessions: 2 (estimated)
- Buffer (20%): 1 session
- Available: 1-2 focused sessions

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S4-01 | Cursor spawn scale-in animation | Board Renderer | S | None | Cursor scales 0→1 over 0.15s on spawn, draws attention |
| S4-02 | Screen shake on contagion capture | Board Renderer | S | None | 2-3px camera offset for 0.2s on capture_contagion events |
| S4-03 | Capture flash effect | Board Renderer | S | None | White flash → player color on captures (more pronounced than current) |
| S4-04 | Tutorial / first-match guidance | UI | M | None | Brief overlay on first launch: "Cursor appears → press direction to act → chains sweep through enemies" with skip button |
| S4-05 | Player color legend on board | HUD | S | None | Small color-name key showing which color = which player during match |
| S4-06 | Contagion threshold indicator | Board Renderer | S | None | Show "2/3" style progress toward capture on contagion cells |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S4-07 | Volume slider in config | Config Screen | S | None | Master volume slider 0-100%, persisted in settings |
| S4-08 | Fullscreen toggle | Config Screen | S | None | Checkbox or F11 to toggle fullscreen |
| S4-09 | Scoring curve selectors in config | Config Screen | M | None | Dropdown per scoring category: POW2/COUNT/FIB/SQUARE/CUSTOM with live preview update |
| S4-10 | Max actions slider in config | Config Screen | S | None | Slider for max_actions (0=unlimited to 999) |
| S4-11 | Bonus castle visual indicator | Board Renderer | S | None | Star/sparkle overlay on cells in the player's bonus stack |
| S4-12 | Pause menu (Escape during match) | UI | S | None | Pause overlay: Resume / Settings / Quit; match timer paused |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S4-13 | Board shape variants (diamond, hourglass) | Board State | M | None | Blocked cells creating non-rectangular board shapes |
| S4-14 | Pre-placed castles option | Config Screen | S | S4-13 | Some cells start owned for asymmetric starts |
| S4-15 | Replay / match history | Match Flow | M | None | Save EventLog to file; load and replay step-by-step |
| S4-16 | Online leaderboard (web version) | Web | L | None | Post scores to a simple API; show top scores |
| S4-17 | Particle effects on capture | VFX | S | None | Simple Godot GPUParticles2D burst on castle captures |

## Carryover from Sprint 3

| Task | Reason | New Estimate |
|------|--------|-------------|
| S3-16 Cursor spawn animation | Now S4-01 | S |
| S3-17 Screen shake | Now S4-02 | S |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Tutorial text overwhelming new players | Medium | Medium | Keep it to 3 short lines max; dismiss on any input |
| Scoring curve config adding too many options | Low | Medium | Hide behind "Advanced Scoring" collapsible section |
| Board shape variants need GDD work | Medium | Low | Design the blocked-cell system before implementing |

## Dependencies on External Factors
- None — all features use built-in Godot capabilities

## Definition of Done for this Sprint
- [ ] All Must Have tasks (S4-01 through S4-06) completed
- [ ] Visual juice feels satisfying (screen shake, flash, scale-in)
- [ ] New players can understand the game from the tutorial overlay
- [ ] 190+ tests passing
- [ ] Tagged as v1.2.0, deployed to GitHub Pages
