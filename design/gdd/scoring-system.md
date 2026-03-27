# Scoring System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-03-27
> **Implements Pillar**: Foundation — scoring math used by Rules Engine and Match Flow

## Overview

The Scoring System owns the curve evaluation function and all point calculations in Crystal Kingdoms. It is a stateless math library: given a curve type, multiplier, adjustment, and input value, it returns an effective score. The Rules Engine calls it during action resolution to compute points_delta for each event. Match Flow calls it to check win conditions. The HUD reads accumulated scores for display. The Scoring System does not track scores itself — it only computes them.

## Player Fantasy

Scoring is felt through the numbers that pop up during play — the escalating rewards for building territory, the satisfying spike when a contagion capture pays off, the sting of losing a well-connected castle. The fantasy is that smart play is visibly rewarded: players can see their score climbing faster when they play strategically rather than randomly.

## Detailed Rules

### Core Rules

#### Curve Evaluation Function

The single core function used by all scoring calculations:

```
effective(n: int, curve: CurveType, multiplier: float, adjustment: float) -> int:
    raw = curve_value(n, curve)
    scaled = raw * multiplier + adjustment
    return max(1, round_half_up(scaled))
```

#### Curve Value Functions

```
curve_value(n: int, curve: CurveType) -> int:
    match curve:
        POWER_OF_TWO: return pow(2, n - 1)       // 1, 2, 4, 8, 16...
        COUNT:        return n                     // 1, 2, 3, 4, 5...
        FIBONACCI:    return fib_lookup[n]         // fib(n+1): 1, 2, 3, 5, 8...
        SQUARE:       return n * n                 // 1, 4, 9, 16, 25...
        CUSTOM:       return custom_values[min(n - 1, len(custom_values) - 1)]
```

#### Round Half Up

```
round_half_up(value: float) -> int:
    return floor(value + 0.5)
```

This ensures: 0.5→1, 1.5→2, 2.5→3 (consistent upward rounding at midpoints).

#### Fibonacci Lookup

Precomputed table, indexed 1..12 (max grid 12×12 = 144 cells):

| n | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|----|----|-----|
| value | 1 | 2 | 3 | 5 | 8 | 13 | 21 | 34 | 55 | 89 | 144 | 233 |

For n > 12, extend dynamically or clamp to index 12.

#### Score Accumulation

The Scoring System does NOT track player scores. Score tracking is owned by Match Flow, which maintains per-player totals. The flow is:

1. Rules Engine resolves an action → produces events with `points_delta`
2. Match Flow receives events → adds each `points_delta` to the actor's score
3. Match Flow checks win condition: `score >= winning_score` (if winning_score > 0)

#### Effective Value Preview

The Scoring System provides a preview function for the Menu System UI:

```
preview_curve(curve: CurveType, multiplier: float, adjustment: float, custom: int[]) -> int[]:
    // Returns effective values for n=1..5 for display in config screens
    return [effective(n, curve, multiplier, adjustment) for n in 1..5]
```

### States and Transitions

The Scoring System is stateless — pure functions only. No lifecycle, no initialization, no cleanup.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Game Config** | This reads | Curve selectors, multipliers, adjustments, custom arrays, `lone_castle_scores_zero`, `scoring_mode`. Note: `winning_score` is read by Match Flow, not by Scoring System |
| **Board State** | This reads | `count_adjacent_owned()` — called indirectly via Rules Engine |
| **Rules Engine** | Rules Engine calls this | `effective()` for each event's points_delta calculation |
| **Match Flow** | Match Flow calls this | Score accumulation and win condition checking |
| **HUD / Score Panel** | HUD reads | Reads accumulated scores from Match Flow (not directly from Scoring System) |
| **Menu System** | Menu System calls this | `preview_curve()` to show effective values alongside config selectors |

## Formulas

All formulas are defined in [Game Config — Formulas](game-config.md#formulas). The Scoring System is the implementation of those formulas. No additional formulas beyond the curve evaluation function and its variants.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| n = 0 | Depends on context: for adjacency with `lone_castle_scores_zero` = true → 0; otherwise → 1 (minimum clamp). **Callers must guard n=0 before calling `effective()`** — the Scoring System never sees n=0 | Rules Engine owns the n=0 branch; Scoring System's `max(1, ...)` clamp would override a zero |
| n > 12 for Fibonacci | Extend lookup dynamically or clamp to fib(13) = 233 | Unlikely in practice (would need 12+ adjacent or 12+ owned) but handle gracefully |
| Custom array shorter than n | Repeat last value: `custom_values[len - 1]` | Prevents index-out-of-bounds |
| Multiplier produces fractional result | `round_half_up` — 0.5 rounds up | Consistent rounding behavior |
| Adjustment produces negative result | Clamped to 1 by `max(1, ...)` | Minimum 1 point per event (except lone_castle_scores_zero case) |
| ONLY_CASTLES mode contagion scoring | Rules Engine passes 0 directly, does not call Scoring System for contagion | Mode check happens before scoring call |
| Very high multiplier (e.g., 10.0) on SQUARE curve at n=12 | 144 × 10.0 = 1440 points | Valid — extreme configs produce extreme scores. Player chose this |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **Game Config** | This depends on Game Config | Reads all scoring parameters (hard) |
| **Board State** | This depends on Board State | Reads adjacency counts indirectly via Rules Engine (soft — Scoring System doesn't call Board State directly) |
| **Rules Engine** | Rules Engine depends on this | Calls effective() for point calculations (hard) |
| **Match Flow** | Match Flow reads pre-computed scores from EventLogs | Match Flow does not call Scoring System directly — it reads `points_delta` values already computed by Rules Engine via Scoring System (indirect) |
| **Menu System** | Menu System depends on this | preview_curve() for config UI (soft) |

## Tuning Knobs

The Scoring System has no independent tuning knobs. All tuning lives in Game Config:
- Curve selectors, multipliers, and adjustments for each scoring category
- `lone_castle_scores_zero`
- `scoring_mode`

See [Game Config — Tuning Knobs](game-config.md#tuning-knobs) for the full list.

## Acceptance Criteria

- [ ] `effective()` returns correct values for all 5 curve types at n=1..12
- [ ] POWER_OF_TWO: 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048
- [ ] COUNT: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
- [ ] FIBONACCI: 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233
- [ ] SQUARE: 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144
- [ ] CUSTOM: returns correct indexed values with last-value repeat for overflow
- [ ] `round_half_up` produces: 0.5→1, 1.5→2, 2.5→3, 3.4→3, 3.6→4
- [ ] `max(1, ...)` clamp: negative or zero results become 1
- [ ] Multiplier of 1.0 and adjustment of 0.0 returns raw curve value (identity)
- [ ] `preview_curve()` returns array of 5 effective values matching manual calculation
- [ ] Scoring System is stateless — no side effects, deterministic
- [ ] No hardcoded scoring values — all from Game Config
