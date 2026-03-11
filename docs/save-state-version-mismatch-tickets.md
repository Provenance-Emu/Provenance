# Save State Version Mismatch — Ticket Set

**Priority:** High (next release)  
**Labels:** `save-states`, `core-version`, `high-priority`, `agent-work`  
**Epic:** Save state compatibility across core updates

## Background

When emulator cores are updated, save states may become incompatible. Recent PicoDrive updates have caused 32X save states to fail loading, and "Reset Game" does not work when a bad save state is loaded. Core and core version are already tracked in Realm, SwiftData, JSON serialized files, and CloudKit records, but the UI does not consistently check or warn users before loading.

---

## Master Ticket: Save State Version Mismatch Detection & UX

**Labels:** `save-states`, `core-version`, `high-priority`, `agent-work`

### Objective

Introduce a unified flow to check save states against the current core version before load, present clear UI when there is a version mismatch, and allow users to load anyway with an explicit warning that the save may be broken or buggy.

### Acceptance Criteria

- [ ] All save-state launch paths perform a version check before load
- [ ] Version mismatch shows a clear alert/sheet with option to "Load Anyway" or "Cancel"
- [ ] User can proceed with load after acknowledging the risk
- [ ] Wiki/settings link to save state version info when available

### Affected Launch Paths

| Path | File(s) | Current Behavior |
|------|---------|------------------|
| In-emulator Save States menu | `PVSaveStatesViewController`, `PVEmulatorViewController+Saves` | Version check exists in `loadSaveState`; shows warning but still loads |
| ContinuesManagementView | `ContinuesMagementView.swift`, `SaveStateRowView` | No version check; `onLoadSave` goes to parent |
| RetroSaveStatesStore | `RetroSaveStatesBrowserView.swift` | `openSaveState` → `SceneCoordinator.launchSaveState`; no version check |
| TVMediaMainView | `TVMediaMainView.swift` | Same as RetroSaveStatesStore |
| RetroGameLibraryView | `RetroGameLibraryView.swift` | Same store |
| GameLaunchingViewController | `GameLaunchingViewController.swift` | `openSaveState` loads directly; no version check |
| Deep link / App open | `ProvenanceApp.swift`, `PVRootViewController` | `openSaveStateID` → launch flow; no version check |

### Data Model Status

- **Realm** `PVSaveState`: `createdWithCoreVersion` ✅
- **SwiftData** `SaveState_Data`: `createdWithCoreVersion` ✅
- **CloudKit**: `coreVersion` in schema ✅
- **PVPrimitives** `SaveState`: No `createdWithCoreVersion` in protocol/struct — needs addition for JSON round-trip
- **SaveStateRowViewModel** / **RetroSaveStateItem**: No `createdWithCoreVersion` — needs addition for UI checks

---

## Sub-Ticket 1: Add `createdWithCoreVersion` to Save State View Models

**Labels:** `save-states`, `core-version`, `agent-work`

### Objective

Ensure `createdWithCoreVersion` (and optionally `coreIdentifier`) flows from Realm/SwiftData into all view models and DTOs used by save-state UIs.

### Acceptance Criteria

- [ ] `SaveStateRowViewModel` includes `createdWithCoreVersion: String?` and `coreIdentifier: String?`
- [ ] `RetroSaveStateItem` includes `createdWithCoreVersion: String?` and `coreIdentifier: String?`
- [ ] `RealmSaveStateDriver` and `RetroSaveStatesStore.mapSaveState` populate these fields
- [ ] `PVPrimitives.SaveState` and `SaveStateInfoProvider` include `createdWithCoreVersion` for JSON/CloudKit parity

### Affected Modules

- `PVUI` (SaveStateRowViewModel, RealmSaveStateDriver, RetroSaveStatesBrowserView)
- `PVPrimitives` (SaveState)
- `PVLibrary` (CloudKit schema already has it)

---

## Sub-Ticket 2: Centralized Version Mismatch Check & Alert Flow

**Labels:** `save-states`, `core-version`, `agent-work`

### Objective

Create a shared service or helper that compares `createdWithCoreVersion` with the current core’s `projectVersion` and presents a consistent alert/sheet before load.

### Acceptance Criteria

- [ ] New helper: `SaveStateVersionChecker` or similar, with `checkAndWarnIfMismatch(saveState:core:onLoad:onCancel:) async -> Bool`
- [ ] Uses `PVSaveState.createdWithCoreVersion` vs `PVCore.projectVersion`
- [ ] Presents `RetroAlertState` or equivalent with "Load Anyway" / "Cancel"
- [ ] Returns whether user chose to proceed
- [ ] Handles nil/empty `createdWithCoreVersion` (treat as unknown, optional warning)

### Affected Modules

- `PVUI` (new helper, `SceneCoordinator`, `RetroAlertState`)

---

## Sub-Ticket 3: Integrate Version Check into All Save-State Launch Paths

**Labels:** `save-states`, `core-version`, `agent-work`

### Objective

Wire the centralized version check into every path that can load a save state.

### Acceptance Criteria

- [ ] **SceneCoordinator.launchSaveStateWithValidation**: Before launching, call version check; if mismatch and user cancels, abort
- [ ] **ContinuesManagementView** (onLoadSave): Before calling parent’s load, resolve core and run version check
- [ ] **PVEmulatorViewController+Saves.loadSaveState**: Already has check; ensure it uses shared helper and allows "Load Anyway"
- [ ] **GameLaunchingViewController.openSaveState**: Add version check when loading into running game
- [ ] **RetroSaveStatesStore.openSaveState** → `launchSaveState`: Covered by SceneCoordinator integration
- [ ] **Deep link** `openSaveStateID`: Covered by SceneCoordinator integration

### Affected Modules

- `PVUI` (SceneCoordinator, ContinuesManagementView, PVEmulatorViewController+Saves, GameLaunchingViewController)

---

## Sub-Ticket 4: Reset Game with Bad Save State (PicoDrive / General)

**Labels:** `save-states`, `reset`, `picodrive`, `agent-work`

### Objective

Investigate why "Reset Game" does not work when a save state fails to load or is incompatible. In theory, reset should boot the game without patching save memory.

### Acceptance Criteria

- [ ] Reproduce reset failure with PicoDrive 32X and incompatible save state
- [ ] Trace `resetEmulation` flow: `RetroMenuView` → `core.resetEmulation()` → `PVLibRetroCore.resetEmulation` / PicoDrive `retro_reset()`
- [ ] Determine if the issue is: (a) core state corrupted by failed load, (b) save RAM still patched, (c) core-specific bug
- [ ] Document findings and implement fix if possible (may be core-specific)

### Notes

- PicoDrive `resetEmulation` calls `retro_reset()` (libretro API)
- If load state fails mid-way, core may be in inconsistent state; reset might not fully reinitialize
- Consider: Should we auto-reset or re-load ROM when load state fails?

### Affected Modules

- `PVUI` (RetroMenuView, emulator flow)
- `Cores/PicoDrive` (PVPicoDriveBridge — do not modify upstream libpicodrive)
- `PVCoreBridgeRetro` (PVLibRetroCore)

---

## Sub-Ticket 5: Save State Porting / Conversion (Exploratory)

**Labels:** `save-states`, `core-version`, `research`, `agent-work`

### Objective

Explore whether save states can be "ported" to newer core versions, either via core-provided conversion or app-side transformers.

### Acceptance Criteria

- [ ] Survey cores for built-in save state version handling (e.g. Mednafen `load` parameter in `MDFNSS_StateAction`)
- [ ] Document which cores support versioned save states
- [ ] If cores expose conversion hooks, design integration point
- [ ] If not, assess feasibility of app-side transformers from git diffs (low confidence)

### Notes

- Mednafen passes version to `StateAction`; some cores may support backward compatibility
- App-side transformation is high effort and error-prone; document as future research

---

## Sub-Ticket 6: Wiki & In-App Save State Documentation

**Labels:** `save-states`, `docs`, `wiki`, `agent-work`

### Objective

Add or link to wiki content about save state version mismatches and best practices.

### Acceptance Criteria

- [ ] Create or update page in `provenance-emu/wiki` (e.g. `save-states/version-mismatches.md`)
- [ ] Content: what version mismatch means, why it happens, how to avoid (create new save after core update), "Load Anyway" risks
- [ ] In-app wiki browser can link to this page (e.g. from version mismatch alert or Settings)
- [ ] Wiki content is built into app via existing script/action (see `PVHelp`, `WikiConstants`)

### Notes

- Wiki repo: `Provenance-EMU/wiki` (https://github.com/Provenance-EMU/wiki)
- App fetches from `https://raw.githubusercontent.com/Provenance-EMU/wiki/master/`

---

## Test Plan (All Tickets)

- [ ] `swift build` passes for affected modules
- [ ] `swiftlint` reports no new violations
- [ ] Manual: Launch save state from ContinuesManagementView with version mismatch → see alert, can load anyway
- [ ] Manual: Launch save state from TVMediaMainView with version mismatch → same
- [ ] Manual: Launch save state from in-emulator menu with version mismatch → same
- [ ] Manual: PicoDrive 32X — load old save, try reset → document/fix behavior

---

## Context

- `PVEmulatorViewController+Saves.loadSaveState` (lines 111–121): Existing version check; shows `presentWarning` but still proceeds
- `PVSaveState.createdWithCoreVersion`, `SaveState_Data.createdWithCoreVersion`, CloudKit `coreVersion`
- `RetroSaveStatesStore.openSaveState` → `SceneCoordinator.launchSaveState` → `launchSaveStateWithValidation`
- PicoDrive: `retro_reset()` in `resetEmulation`; `loadSaveFile` for battery saves on ROM load
