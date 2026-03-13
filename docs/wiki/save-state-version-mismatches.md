# Save State Version Mismatch

Provenance records the emulator core version that was used when each save state
was created. When you update the app (or switch cores), the version string stored
with a save state may no longer match the currently installed core.

A mismatch does **not** necessarily mean the save state is broken — many minor
core updates are forwards/backwards compatible. Provenance warns you so you can
decide whether to load it.

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

## What happens when I load a mismatched save state?

Provenance shows a confirmation dialog before loading:

> **Save State Version Mismatch**
>
> This save state was created with *\<Core Name\>* version **X.Y.Z**, but the
> currently installed version is **A.B.C**. The save state may be incompatible.
>
> **[Load Anyway]** · **[Cancel]**

- **Load Anyway** — Provenance attempts to restore the state. If the core
  accepts it, gameplay continues normally. If the core rejects it, a second
  dialog offers a **Reset Game** option to restore a clean emulator state.
- **Cancel** — Returns to the save state browser without loading anything.

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

## What should I do if a save state fails to load?

1. Tap **Reset Game** in the error dialog. This performs a software reset
   (equivalent to pressing the Reset button on the original hardware) and
   returns the game to its start screen.
2. If the game is still behaving oddly after reset, exit to the library and
   re-launch the game from scratch. This performs a full emulator
   reinitialisation.
3. If you have a save state from a compatible core version, try loading that
   instead.

## "Load Anyway" — What Are the Risks?

If you choose to load a save state despite a version mismatch:

- **Load may fail** — The core may reject the file or crash.
- **Corruption** — The game might run with glitches, wrong graphics, or corrupted data.
- **Reset may not work** — In some cores, resetting after a failed load can leave the emulator in a bad state.

When in doubt, create a new save state with the updated core.

## Can Provenance convert old save states automatically?

Not in general. The libretro API treats save states as **opaque binary blobs**
— there is no standard version header or migration hook that Provenance can use
to transform a save state from one core version to another.

Some cores (e.g. Mednafen-based cores) embed their own version information and
handle migration internally, but this is transparent to Provenance and is not
guaranteed across major version bumps.

A future enhancement (tracked in [#2951](https://github.com/Provenance-Emu/Provenance/issues/2951))
would require a `retro_get_state_version()` API addition to libretro and
per-core migration callbacks.

## Tips for keeping save states working across updates

- **Use in-game saves** (battery saves / memory cards) whenever the game
  supports them. These are stored in the game's own format and are far more
  resilient to core updates than save states.
- **Pin important save states.** Pinned states are never auto-purged and are
  easy to find in the save state browser.
- **Check the release notes** before updating. If a core update notes
  "save state format changed", make an in-game save before updating.

## Technical Details

- Save states track the core version they were created with: `createdWithCoreVersion` in Realm (stored in CloudKit as `coreVersion` from `PVSaveState.createdWithCoreVersion`).
- The app checks this against `core.projectVersion` before load.
- You can always choose to load anyway; the warning is informational.

## Related

- [Save States overview](https://wiki.provenance-emu.com/save-states/) — full save-states section of the wiki
- [GitHub issue #2951 — Save State Version Mismatch Detection & UX](https://github.com/Provenance-Emu/Provenance/issues/2951)
