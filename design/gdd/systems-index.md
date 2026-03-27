# Systems Index: Crystal Kingdoms

> **Status**: Approved
> **Created**: 2026-03-26
> **Last Updated**: 2026-03-26
> **Source Concept**: GAME_OUTLINE.md, docs/mvp-plan.md

---

## Overview

Crystal Kingdoms is a strategic turn-based grid game where players race to capture
castles through cursor-based action racing and contagion mechanics. The systems
scope covers: a deterministic rules engine with event-driven resolution, real-time
cursor claim racing, chain traversal across the board, configurable scoring modes,
CPU AI with difficulty tiers, local multiplayer input routing, and a 2D sprite-based
renderer using existing 64x64 castle and cursor assets.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Game Config | Core | MVP | Approved | [design/gdd/game-config.md](game-config.md) | — |
| 2 | Board State | Core | MVP | Approved | [design/gdd/board-state.md](board-state.md) | Game Config |
| 3 | Rules Engine | Gameplay | MVP | Approved | [design/gdd/rules-engine.md](rules-engine.md) | Board State, Game Config, Scoring System |
| 4 | Scoring System | Gameplay | MVP | Approved | [design/gdd/scoring-system.md](scoring-system.md) | Board State, Game Config |
| 5 | Input System | Core | MVP | Approved | [design/gdd/input-system.md](input-system.md) | Game Config |
| 6 | Turn Director | Gameplay | MVP | Approved | [design/gdd/turn-director.md](turn-director.md) | Board State, Rules Engine, Input System, Game Config |
| 7 | CPU Controller | Gameplay | MVP | Approved | [design/gdd/cpu-controller.md](cpu-controller.md) | Board State, Rules Engine, Game Config |
| 8 | Match Flow | Gameplay | MVP | Approved | [design/gdd/match-flow.md](match-flow.md) | Turn Director, Rules Engine, Scoring System, CPU Controller, Game Config |
| 9 | Board Renderer | UI | MVP | Approved | [design/gdd/board-renderer.md](board-renderer.md) | Board State, Match Flow |
| 10 | HUD / Score Panel | UI | MVP | Approved | [design/gdd/hud-score-panel.md](hud-score-panel.md) | Scoring System, Match Flow |
| 11 | Settings Manager | Persistence | Vertical Slice | Not Started | — | Game Config |
| 12 | Scene Management | Core | Vertical Slice | Not Started | — | — |
| 13 | Menu System | UI | Vertical Slice | Not Started | — | Game Config, Settings Manager, Input System, Scene Management |
| 14 | Animation/VFX | UI | Alpha | Not Started | — | Board Renderer, Match Flow |
| 15 | Audio System | Audio | Alpha | Not Started | — | Match Flow, Menu System |

---

## Categories

| Category | Description |
|----------|-------------|
| **Core** | Foundation systems everything depends on |
| **Gameplay** | Deterministic game logic — rules, turns, AI, match orchestration |
| **UI** | Visual presentation — renderer, HUD, menus, animations |
| **Persistence** | Save/load player configs and game options |
| **Audio** | Sound effects and music |

---

## Priority Tiers

| Tier | Definition | Systems Count |
|------|------------|---------------|
| **MVP** | Required for the core loop — cursor spawn, claim race, action resolution, scoring, visual board | 10 |
| **Vertical Slice** | Complete experience with menus, settings persistence, scene transitions | 3 |
| **Alpha** | Polish layer — animations, VFX, audio feedback | 2 |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Game Config** — pure data container for all tunables; 8 systems read from it
2. **Board State** — grid data model; 6 systems depend on it
3. **Scene Management** — Godot scene transitions (VS priority, not needed for MVP)

### Core Layer (depends on foundation)

1. **Input System** — depends on: Game Config
2. **Rules Engine** — depends on: Board State, Game Config
3. **Scoring System** — depends on: Board State, Game Config
4. **Settings Manager** — depends on: Game Config

### Feature Layer (depends on core)

1. **Turn Director** — depends on: Board State, Rules Engine, Input System, Game Config
2. **CPU Controller** — depends on: Board State, Rules Engine, Game Config
3. **Match Flow** — depends on: Turn Director, Rules Engine, Scoring System, CPU Controller, Game Config

### Presentation Layer (depends on features)

1. **Board Renderer** — depends on: Board State, Match Flow
2. **HUD / Score Panel** — depends on: Scoring System, Match Flow
3. **Menu System** — depends on: Game Config, Settings Manager, Input System, Scene Management
4. **Animation/VFX** — depends on: Board Renderer, Match Flow

### Polish Layer

1. **Audio System** — depends on: Match Flow, Menu System

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | Game Config | MVP | Foundation | S |
| 2 | Board State | MVP | Foundation | S |
| 3 | Rules Engine | MVP | Core | M |
| 4 | Scoring System | MVP | Core | S |
| 5 | Input System | MVP | Core | S |
| 6 | Turn Director | MVP | Feature | M |
| 7 | CPU Controller | MVP | Feature | S |
| 8 | Match Flow | MVP | Feature | M |
| 9 | Board Renderer | MVP | Presentation | M |
| 10 | HUD / Score Panel | MVP | Presentation | S |
| 11 | Settings Manager | Vertical Slice | Core | S |
| 12 | Scene Management | Vertical Slice | Foundation | S |
| 13 | Menu System | Vertical Slice | Presentation | M |
| 14 | Animation/VFX | Alpha | Presentation | M |
| 15 | Audio System | Alpha | Polish | M |

Effort estimates: S = 1 session, M = 2-3 sessions.

---

## Circular Dependencies

None found.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Board State | Scope | Bottleneck — 6 systems depend on it. Bad data model ripples everywhere | Design thoroughly; prototype early; lock the API before building dependents |
| Game Config | Scope | 8 dependents. Adding options late forces rework across systems | Define the full option set upfront; use Godot Resources for data-driven config |
| Turn Director | Technical | Real-time cursor claim racing with multiple input sources is timing-sensitive | Prototype the spawn→claim→resolve loop standalone before integrating |
| Rules Engine | Design | Chain resolution + contagion + scoring interactions are combinatorially complex | Port existing TypeScript logic; validate with the 178 existing test cases |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 15 |
| Design docs started | 10 |
| Design docs reviewed | 10 |
| Design docs approved | 10 |
| MVP systems designed | 10/10 |
| Vertical Slice systems designed | 0/3 |

---

## Next Steps

- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Prototype the Turn Director early (highest technical risk)
