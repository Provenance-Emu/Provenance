# Copilot Instructions for Provenance

## Project Context
Provenance is a multi-platform emulator frontend for iOS/tvOS. The codebase uses Swift with Objective-C++ bridge layers for emulator cores.

## Code Review Focus Areas

### Swift Code
- Prefer `async/await` over Combine where possible
- Use `@Sendable` and proper actor isolation for concurrency
- Avoid force unwraps (`!`) in production code; use `guard let` or `if let`
- Line length limit: 200 characters (`.swiftlint.yml`)
- 4-space indentation, no indent for `case` in `switch`

### Emulator Core Bridges (`*Bridge+Controls.mm`)
- All controller types must be handled: Extended, Micro, Keyboard
- Button mappings must match upstream emulator constants
- Never modify upstream submodule source in `Cores/<name>/<upstream-dir>/`

### Module Architecture
- Each `PV*` module is a standalone Swift Package
- Cross-module dependencies follow a tiered structure (see CLAUDE.md)
- Realm objects are thread-confined: pass Object IDs or freeze for cross-thread access

### What NOT to Flag
- `force_cast` and `force_try` are intentionally warnings, not errors
- Generated files (`Version.h`, `Version.swift`) — skip review
- Submodule contents (`Cores/<name>/<upstream>/`) — skip review
- `project.pbxproj` changes — minimize review noise

### PR Conventions
- Agent PRs use `[Agent]` title prefix
- Target branch is always `develop`
- Conventional commits: `fix:`, `feat:`, `chore:`, `build:`, `refactor:`, `test:`, `docs:`
