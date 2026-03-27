## Prototype Report: Core Loop

### Hypothesis
The cursor-claim-racing + contagion + chain mechanic creates fun, competitive 2-player gameplay on a 2D grid. Specifically:
1. Racing to claim a cursor creates tension and excitement
2. Contagion (incremental capture) creates strategic depth
3. Chain traversal creates satisfying "big play" moments
4. The combined loop sustains a 3-minute match without becoming repetitive

### Approach
Built a single-file GDScript prototype (~300 lines) with:
- 8x8 grid rendered with `ColorRect` nodes (no sprites)
- 2 keyboard players (WASD+Space, Arrows+Enter)
- Full action resolution: capture, contagion, chain, self-destroy
- Floating point popups for score feedback
- Cell flash animation on actions
- Contagion counters displayed on cells
- 3-minute timer, wrap-around enabled, capture threshold = 3

Shortcuts taken: simplified scoring (adjacency count, not curves), no CPU opponent, no speed presets, hardcoded values, no menu.

### Result
PENDING PLAYTEST - This prototype must be run in Godot 4.6 and playtested by two players to evaluate. The prototype is ready for testing.

### Metrics
- Build time: ~15 minutes (single conversation)
- Lines of code: ~300
- Frame time: Expected <1ms (2D grid, no complex rendering)
- Iteration count: 1 (first implementation)

### Recommendation: PENDING PLAYTEST

The prototype needs hands-on testing before a verdict can be given. Key observations to record during playtesting:

1. **Claim racing feel**: Is the cursor visible and exciting enough? Is the spawn timing right?
2. **Contagion readability**: Can players see contagion building? Is threshold=3 too fast or slow?
3. **Chain satisfaction**: Do directional chains feel powerful? Are they readable?
4. **Match pacing**: Is 3 minutes too long, too short, or about right?
5. **Scoring clarity**: Do the point popups communicate value effectively?

### If Proceeding
- Replace `ColorRect` with actual castle sprites from `images/`
- Implement full scoring curve system (currently simplified)
- Add CPU controller for single-player
- Add sound effects (cursor spawn, capture, chain)
- Implement proper input system with configurable bindings
- Build as separate Godot project in `src/` following ADR architecture

### If Pivoting
- If claim racing feels too frantic: try turn-based with time pressure instead
- If contagion is too opaque: add visual contagion meter instead of text
- If chains feel too random: add chain preview before committing

### If Killing
- If the core loop fails to create tension, the cursor-racing mechanic may not work for 2D grid format. Consider alternative action selection (tile placement, area selection).

### Lessons Learned
- PENDING (will be filled after playtesting)
