# Core Loop Prototype

**PROTOTYPE - NOT FOR PRODUCTION**

## How to Run

1. Open Godot 4.6
2. Import this project: `prototypes/core-loop/project.godot`
3. Press F5 to run

## Controls

| Player | Up | Down | Left | Right | Fire |
|--------|-----|------|------|-------|------|
| Blue (P1) | W | S | A | D | Space |
| Red (P2) | Up | Down | Left | Right | Enter |

## How to Play

1. Wait for the yellow cursor to appear on the grid
2. Race to press Fire first to claim the cursor
3. Hold a direction + Fire = chain action (sweeps in that direction)
4. Fire alone = tap (acts on cursor cell only)

### What happens when you act:
- **Empty cell**: You capture it (turns your color)
- **Enemy cell**: Contagion ticks up (shown as B:1, R:2 etc.)
- **Enemy at contagion 3**: You capture it!
- **Your own cell**: Destroyed (goes empty)

### Chains:
- Chains continue through enemy cells that aren't captured
- Chains stop on: empty capture, contagion capture, self-destroy, or board edge

## What to Test

- Does the cursor-racing feel exciting?
- Does contagion create interesting decisions (harass vs. capture)?
- Are chains satisfying when they sweep across enemy territory?
- Does the scoring feel rewarding?
- Is the 3-minute match length appropriate?
- Does wrap-around add tactical depth?
