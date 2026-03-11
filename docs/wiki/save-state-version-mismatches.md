# Save State Version Mismatches

Save states capture the exact memory and CPU state of an emulator at a moment in time. When an emulator core is updated, the internal format of save states can change. Loading a save state created with an older core version into a newer core (or vice versa) may fail or cause bugs.

## What is a Version Mismatch?

Provenance stores the core version used when each save state was created. When you try to load a save state, the app compares:

- **Save state version:** The core version that created the save
- **Current core version:** The core version installed on your device

If these differ, you may see a warning before loading.

## Why Does This Happen?

Emulator cores are actively developed. Updates can:

- Change how save state data is serialized
- Add or remove features that affect saved state
- Fix bugs that alter memory layout

Save states are **not** designed to be portable across core versions. They are a snapshot of internal state, not a standardized format.

## What Should I Do?

### Before Loading

If you see a version mismatch warning:

1. **Create a new save state** after updating the core — this ensures compatibility.
2. **Load anyway** only if you understand the save may fail or behave incorrectly.
3. Consider keeping a backup of important saves before updating cores.

### After a Core Update

1. Start the game fresh (or from a save state made with the new core).
2. Create a new save state at your desired point.
3. Old save states may no longer work reliably.

## "Load Anyway" — What Are the Risks?

If you choose to load a save state despite a version mismatch:

- **Load may fail** — The core may reject the file or crash.
- **Corruption** — The game might run with glitches, wrong graphics, or corrupted data.
- **Reset may not work** — In some cores, resetting after a failed load can leave the emulator in a bad state.

When in doubt, create a new save state with the updated core.

## Technical Details

- Save states track the core version they were created with: `createdWithCoreVersion` in Realm/SwiftData (stored in CloudKit as `coreVersion` from `PVSaveState.createdWithCoreVersion`).
- The app checks this against `core.projectVersion` before load.
- You can always choose to load anyway; the warning is informational.

## Related

- [Game Saves](saves.md) — Overview of save states and battery saves
- [Quick Continue](quick-continue.md) — Using save states to resume games
