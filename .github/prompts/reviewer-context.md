# Provenance AI Reviewer — Project Context

This file is injected into every AI review session. Keep it concise.

---

## Module Dependency Tiers

Higher tiers may import lower tiers. **Never the reverse.**

| Tier | Modules |
|------|---------|
| 0 | PVObjCUtils, PVFeatureFlags, PVCheevos |
| 1 | PVLogging, PVPlists, PVHashing |
| 2 | PVSettings, PVPrimitives |
| 3 | PVSupport, PVAudio, PVCoreAudio |
| 4 | PVCoreBridge, PVEmulatorCore, PVShaders |
| 5 | PVCoreBridgeRetro, PVCoreLoader, PVLookup, PVLibrary, PVRealm |
| 6 | PVUI, App targets (Provenance, ProvenanceTV) |

---

## Critical Patterns & What To Check

### Realm Thread Safety (🔴 CRITICAL if violated)
- Realm objects are **thread-confined**. Never pass a live `Object` or `Results<T>`
  across thread/actor boundaries — this crashes at runtime.
- Safe cross-thread patterns: pass primary keys (String/Int) and re-fetch,
  or call `.freeze()` before crossing. Freeze objects are read-only.
- `Results<T>` must NOT be captured across `async`/`await` suspension points.
- Write transactions: always inside `try realm.write { }`. Check for
  `realm.isInWriteTransaction` before nesting.

### SwiftData / @Model (🔴 for iOS 17+ gated code)
- `ModelContext` is **NOT Sendable** — do not pass across actor boundaries.
- `ModelContext(ModelContainer)` is non-@MainActor in iOS 18 SDK; check for
  older availability guards if targeting iOS 17 minimum.
- `@Relationship` must specify `deleteRule` or it defaults to `.nullify`
  (orphans on delete).
- `@Attribute(.unique)` required on any field used as a primary key.
- Lazy sequences from `realm.objects(...).map(...)` must be materialized with
  `Array(...)` before crossing an actor hop.

### ObjC/C++ Emulator Bridges (🟠 MAJOR if unguarded)
- Files: `PV*CoreBridge+Controls.mm`, `PVLibRetroCore.m`
- Input event callbacks (touchBegan, handleMouseEvent) run on the UI/main thread.
- The libretro core polling (`getPointerState:`, `getInput:`) runs on the
  emulator thread.
- Any flag written from one thread and read from the other **must** be guarded
  with `@synchronized(self)`. Both the write AND the read side need the lock.
- GCController callbacks: run on main thread. Emulator: its own thread.

### Actor Isolation / async-await
- `@MainActor` annotated code must not be called from non-main actors without
  `await MainActor.run { }`.
- Custom actors (`public actor Foo`) cannot use non-Sendable types across their
  isolation boundary.
- `nonisolated(unsafe)` is valid for stored properties that are only mutated
  before concurrent access begins (e.g., during init).

### Public API Surface
- Only expose what callers outside the module actually need.
- Changing `internal` → `public` on Realm model properties is only acceptable
  when another module's migration code genuinely requires read access.
  Flag unnecessary `public` promotions.

### Module Boundaries
- Submodule upstream source (`Cores/<name>/<upstream-dir>/`) must **never** be
  modified. Flag immediately as 🔴 CRITICAL.
- `project.pbxproj` changes are always suspicious — flag if unnecessary.
- SPM `Package.swift` changes: verify dependency tiers not violated.

---

## What NOT to Flag (Avoid Noise)

- `force_cast` / `force_try` inside established patterns with clear invariants —
  these are warnings in SwiftLint, not errors. Only flag if in a critical
  execution path with real crash risk.
- Line length up to 200 chars — enforced by SwiftLint, only flag obvious
  readability issues over 200.
- Copilot/AI co-author lines in commits.
- `@available` annotations that already match the iOS 17/tvOS 17 targets.
- Comments explaining historical context or TODOs — not actionable unless wrong.

---

## Common Severity Guide

| Severity | Examples |
|----------|---------|
| 🔴 CRITICAL | Realm object crossing thread boundary, force-unwrap of nil-able, crash-able libretro pointer dereference, upstream submodule modification |
| 🟠 MAJOR | Unsynchronized flag read/write on different threads, ModelContext passed as Sendable, tier dependency violation, missing deleteRule on @Relationship |
| 🟡 MINOR | Unnecessary public exposure, misleading naming, missing availability guard |
| ⚪ NIT | Style-only, whitespace, trivial naming preference |

---

## Project Conventions

- **Swift**: 4-space indent, no indent for `case`, trailing commas in collections
- **Obj-C**: 4-space indent, `@synchronized(self)` for thread safety (not `os_unfair_lock`)
- **SwiftLint**: `.swiftlint.yml` at repo root — 200-char lines, force_cast=warning
- **Xcode**: 16.2 (`/Applications/Xcode_16.2.app`), iOS/tvOS 17+ deployment target
- **Platforms**: iOS + tvOS. Both must compile. Check `#if os(tvOS)` guards where needed.
- **Branches**: `agent/**` for agent work, `feature/**` for human features, PR to `develop`
- **Commit style**: conventional commits (`fix:`, `feat:`, `chore:`, `build:`, `refactor:`)
