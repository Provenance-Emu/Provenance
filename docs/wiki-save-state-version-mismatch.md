# Save State Version Mismatch

> **Note:** This file is **deprecated** and kept only for backwards compatibility.
> The **canonical** template now lives at
> [`docs/wiki/save-state-version-mismatches.md`](wiki/save-state-version-mismatches.md)
> alongside the other wiki docs.
> When publishing to the [Provenance-EMU/wiki](https://github.com/Provenance-EMU/wiki)
> repository, copy the contents from that canonical file to
> `save-states/version-mismatch.md` in the wiki repo and update `SUMMARY.md`
> accordingly. The path `save-states/version-mismatch.md` matches the
> `WikiConstants.Paths.saveStateVersionMismatch` constant used for in-app linking.

---

## What is a save state version mismatch?

Provenance records the emulator core version that was used when each save state
was created. When you update the app (or switch cores), the version string stored
with a save state may no longer match the currently installed core.

A mismatch does **not** necessarily mean the save state is broken — many minor
core updates are forwards/backwards compatible. Provenance warns you so you can
decide whether to load it.

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

## What should I do if a save state fails to load?

1. Tap **Reset Game** in the error dialog. This performs a software reset
   (equivalent to pressing the Reset button on the original hardware) and
   returns the game to its start screen.
2. If the game is still behaving oddly after reset, exit to the library and
   re-launch the game from scratch. This performs a full emulator
   reinitialisation.
3. If you have a save state from a compatible core version, try loading that
   instead.

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

## Related

- [Save States overview](https://github.com/Provenance-EMU/wiki/blob/master/save-states/README.md)
- [Core updates and compatibility](https://github.com/Provenance-EMU/wiki/blob/master/cores/compatibility.md)
- GitHub issue [#2951 — Save State Version Mismatch Detection & UX](https://github.com/Provenance-Emu/Provenance/issues/2951)
