# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical)
- **Rendering**: Vulkan (Forward+) — D3D12 default on Windows in 4.6
- **Physics**: Jolt (default in 4.6)

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables/functions**: snake_case (e.g., `move_speed`)
- **Signals**: snake_case past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: <200 (2D sprite-based grid, 144 cells max + UI)
- **Memory Ceiling**: 512MB

## Testing

- **Framework**: GUT (Godot Unit Test)
- **Minimum Coverage**: 80% on core systems (Rules Engine, Scoring System, Board State)
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [ADR-0001: Event-Driven Game Loop](../../docs/architecture/adr-0001-event-driven-game-loop.md)
- [ADR-0002: Data-Driven Config via Godot Resources](../../docs/architecture/adr-0002-data-driven-config.md)
