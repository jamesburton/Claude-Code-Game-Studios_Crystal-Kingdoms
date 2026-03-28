# Sprint 7 — Board Refinement & Visual Polish

## Sprint Goal
Fix blocked cell chain handling, add neutral castles and reinforced variants, improve danger/bonus visibility, and polish board interactions for all layouts.

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S7-01 | Skip-blank chain behavior | Rules Engine | S | None | `skip_blanks` config (default true): chains skip blocked cells and continue to next playable cell in direction; if false, chain stops at blocked |
| S7-02 | Neutral castles (grey/dark) | Board State | M | None | Cells can be owned by -2 (neutral); must be captured via contagion like enemy castles; no player scores from them defensively |
| S7-03 | Reinforced neutral castles (+1/+2) | Board State | S | S7-02 | `cells_reinforcement` array: 0=normal, 1=reinforced (+1 extra contagion needed, 150% score), 2=fortified (+2 extra, 200% score) |
| S7-04 | Neutral/reinforced config | Config Screen | S | S7-02 | Sliders: neutral_count (0-20), reinforced_count (0-10), fortified_count (0-5) |
| S7-05 | Danger/bonus visual indicators | Board Renderer | S | None | Danger cells: red warning icon/border; Bonus cells: gold star icon/border; visible at all grid sizes |
| S7-06 | Persistent special squares option | Config/Rules | S | None | `persistent_specials` config (default false): when false, capturing danger/bonus/reinforced cell reverts it to normal; when true, retains its type |
| S7-07 | Neutral castle rendering | Board Renderer | S | S7-02 | Grey/dark castle sprite (use empty sprite with grey tint); reinforced has +1/+2 badge |

### Should Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S7-08 | Neutral castle contagion display | Board Renderer | S | S7-02 | Show contagion from all players on neutral castles (multiple gem indicators) |
| S7-09 | Board preview in config | Config Screen | S | None | Small preview of board shape showing blocked/neutral/danger/bonus cell layout |
| S7-10 | Reinforcement sound effects | Audio | S | S7-03 | Distinct SFX for capturing reinforced (deeper tone) and fortified (dramatic chord) |
| S7-11 | Victory celebration animation | UI | S | None | Particle burst + flash when winner shown on end screen |
| S7-12 | Menu hover/click SFX | Audio | S | None | Subtle UI sounds on button interactions |
| S7-13 | Menu transitions (fade) | UI | S | None | 0.3s fade between screens |

### Nice to Have

| ID | Task | System | Est. | Dependencies | Acceptance Criteria |
|----|------|--------|------|-------------|-------------------|
| S7-14 | Custom board editor | UI | M | None | Click cells to toggle blocked/neutral/danger/bonus; save as named preset |
| S7-15 | Match statistics history | Persistence | S | None | Save per-match stats; show historical data |
| S7-16 | High contrast mode | UI | S | None | Toggle for accessibility colors and larger borders |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Skip-blank + wrap-around could create infinite chains | Medium | High | Add max chain length safety (grid_size * 2); cycle detection still applies |
| Neutral castles complicate CPU scoring | Medium | Medium | CPU treats neutrals similarly to enemies but with lower priority |
| Too many cell types make board hard to read | Medium | Medium | Use distinct visual language: color tints + small icons, test at 12x12 |

## Definition of Done
- [ ] All Must Have tasks (S7-01 through S7-07) completed
- [ ] Chains correctly skip blocked cells on Diamond/Cross/Ring boards
- [ ] Neutral castles require contagion to capture, reinforced need extra hits
- [ ] Danger/bonus cells have clear visual indicators at all grid sizes
- [ ] persistent_specials toggle works correctly
- [ ] 200+ tests passing (new: skip-blank chains, neutral contagion, reinforcement)
- [ ] Tagged as v1.6.0
