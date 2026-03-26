# Crash Triage: 3.3.0 vs 3.4.0

## Scope

This note maps the top two production crash signatures reported on live `3.3.0` against current `3.4.0` branch behavior.

## Crash 1: Realm write crash in save-state load

### Reported stack shape

- `PVEmulatorViewController.loadSaveState(_:)`
- `Realm.write`
- `PVSaveState.lastOpened.setter`
- Realm transaction verification (`RLMVerifyInWriteTransaction`)

### Why it crashes in 3.3.0

In tag `3.3.0`, `loadSaveState(_:)` writes directly to the incoming `state` object:

- `try! realm.write { state.lastOpened = Date() }`

The incoming `state` can be frozen or tied to a different Realm/thread context than the local `realm` instance used for the write transaction, which is consistent with the crash signature.

### Current 3.4.0 behavior

`loadSaveState(_:)` now resolves a local live object from the same Realm instance before writing:

- `guard let liveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: state.id) ...`
- `try! realm.write { liveState.lastOpened = Date() }`

This change removes the cross-context write path shown in the crash.

### Commit reference

- `b0591f3d5` (`thin wrapper async saves, fix crash`)

## Crash 2: `PVDesmume2015` runtime crashes

### Policy state

- `Cores/Desmume2015/PVDesmume2015/Core.plist` has `PVDisabled = true`.
- In current launch filtering, disabled cores are only selectable when `Defaults[.unsupportedCores]` is enabled.
- App Store-disabled cores are still hard-hidden in App Store builds.

### 3.3.0 to 3.4.0 gating delta

`3.3.0` had inverted disabled-core registration logic in core import (`registerCore`), which could produce inconsistent disabled-core behavior.

Current code fixes this gating so disabled cores are skipped only when unsupported cores are OFF, and correctly exposed only when unsupported cores are ON.

### Commit reference

- `a2f2eea5c` (`fix(cores): correct PVDisabled/PVAppStoreDisabled filtering logic`)

## Outcome

- Crash #1 appears addressed in current `3.4.0` branch by the live-object Realm write fix.
- `PVDesmume2015` remains intentionally experimental-only and can still crash when users explicitly enable unsupported cores; this is expected under current policy.
