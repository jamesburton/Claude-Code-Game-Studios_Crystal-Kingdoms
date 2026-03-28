# Sprint 6 — Professional Polish, Menus, and Presentation

## Sprint Goal
Transform Crystal Kingdoms from a functional game into a professional-feeling product: studio intro, main menu, options menu, preset modes, attract mode, backgrounds, music, responsive layout, and polished HUD.

## Velocity
Sprints 1-5 delivered all gameplay features in 2 sessions. Sprint 6 focuses entirely on presentation and UX — no new gameplay mechanics.

## Capacity
- Total sessions: 2-3 (estimated)
- Buffer (20%): 1 session
- Available: 2 focused sessions

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S6-01 | Studio intro screen ("Fluffy Productions") | UI | S | None | 2-3s animated splash with studio name/logo, auto-advances to main menu; skippable |
| S6-02 | Main menu screen | UI | M | S6-01 | Play / Options / Quit buttons; game title prominent; background artwork/animation |
| S6-03 | Options menu (moved from config screen) | UI | S | S6-02 | Separate options screen: video (fullscreen, volume), gameplay (all current config options organized into sections) |
| S6-04 | Quick-select preset modes | Config | S | S6-03 | Named presets: "Quick Match" (small grid, fast), "Strategic" (large grid, no tap, low max castles), "Party" (8 players, frantic), "Classic" (defaults); one-click apply |
| S6-05 | User-saved option sets | Persistence | S | S6-03 | Save current settings as named preset to localStorage; load/delete saved presets; list in options |
| S6-06 | Attract mode (idle demo) | UI | M | S6-02 | After 30s idle on main menu, starts CPU vs CPU match with showcase settings; "Press any key" overlay; cycles through board shapes |
| S6-07 | Background artwork/patterns | UI | S | None | Subtle animated background for menu screens (particle field, gradient, or pattern); dark theme behind gameplay board |
| S6-08 | Background music | Audio | M | None | Menu music track + gameplay music track; crossfade on transitions; separate volume from SFX |
| S6-09 | Polished player score HUD | HUD | M | None | Card-style player panels with color bar, score, castles, rank badge; smooth reordering animation; compact mode for 5+ players |
| S6-10 | Responsive portrait/landscape layout | UI | M | None | Board and HUD rearrange for portrait (scores above/below board) vs landscape (scores beside board); smooth transition on resize |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S6-11 | Menu transitions (fade/slide) | UI | S | S6-02 | Smooth transitions between intro → menu → options → game → results |
| S6-12 | Title screen animation | UI | S | S6-02 | Game title with subtle animation (glow, crystal sparkle, or color cycle) |
| S6-13 | Options categories (tabs/accordion) | UI | S | S6-03 | Options grouped: Match / Scoring / Players / Video+Audio; collapsible or tabbed |
| S6-14 | Preset mode descriptions | Config | S | S6-04 | Each preset shows 1-line description of what it changes |
| S6-15 | Attract mode feature showcase | UI | S | S6-06 | Rotate through: different board shapes, player counts, scoring modes between demo matches |
| S6-16 | Pause menu visual polish | UI | S | None | Semi-transparent blur background; styled buttons matching menu theme |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S6-17 | Animated crystal/gem decorations | UI | S | None | Small animated gems in menu corners and HUD borders |
| S6-18 | Match countdown (3-2-1-Go!) | UI | S | None | Brief countdown before match starts, builds anticipation |
| S6-19 | Victory celebration animation | UI | S | None | Particle burst + sound + animation when winner is shown |
| S6-20 | Menu SFX (hover, click, transition) | Audio | S | None | Subtle UI sounds for button hover/press/transition |

## Carryover from Previous Sprint Plan

Networking (S6-04-06 from old plan) moved to Sprint 7. This sprint prioritizes presentation.

| Task | Status |
|------|--------|
| LAN multiplayer | Moved to Sprint 7 |
| Replay viewer UI | Moved to Sprint 7 |
| Keyboard rebinding | Moved to Sprint 7 |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Background music generation quality | Medium | Medium | Use procedural music (arpeggiated chords) or source CC0 tracks |
| Menu complexity getting unwieldy | Medium | Medium | Keep main menu simple (3 buttons); options behind sub-screen |
| Portrait layout breaking board rendering | Medium | High | Test at 9:16, 3:4, 16:9 ratios; use anchors and containers |
| Attract mode interfering with input | Low | Medium | Clear input state when returning from attract; stop demo match cleanly |

## Dependencies on External Factors
- Background music: procedural generation or CC0 audio tracks
- No external services needed

## Definition of Done for this Sprint
- [ ] All Must Have tasks (S6-01 through S6-10) completed
- [ ] Game launches: studio intro → main menu → play/options
- [ ] Attract mode activates after 30s idle, returns cleanly
- [ ] At least 4 named preset modes selectable
- [ ] User can save/load custom named presets
- [ ] Background music plays in menu and gameplay
- [ ] HUD score panels look polished with rank indicators
- [ ] Layout works in both landscape and portrait orientations
- [ ] 200+ tests passing
- [ ] Tagged as v1.5.0
