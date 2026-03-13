# Save State Reset Investigation

**Issue:** Reset Game does not reliably restore a clean emulator state when a save state
fails to load (observed with PicoDrive 32X, potentially other cores).

**Related:** #3077, Part of epic #2951

---

## Root Cause Analysis

### Reset Flow

```
RetroMenuView "RESET GAME" button
  → emulatorVC.core.resetEmulation()
    → PVEmulatorCore+RunLoop: bridge.resetEmulation()
      → PVLibRetroCore.m / PVPicoDriveBridge.m: core->retro_reset()
```

### Save State Load Flow

```
loadSaveState(_ state:)
  → core.loadState(fromFileAtPath:)
    → PVLibRetroCore+Saves.m: core->retro_unserialize(data, size)
```

### The Problem

When `retro_unserialize()` fails (e.g. because the save state was created with an
older PicoDrive version that had a different memory layout), the libretro core may:

- **(a) Partially apply** the state data, leaving internal buffers in an inconsistent
  state (partially overwritten registers, memory maps, etc.)
- **(b) Leave save RAM patched** from the battery-save load that happens at ROM load time,
  but with the game-state data corrupted
- **(c) Have core-specific bugs** where `retro_reset()` does not fully reinitialize
  all state after a failed `retro_unserialize()` (PicoDrive-specific)

Calling `retro_reset()` after case (a) or (c) may not fix the inconsistency because:
- `retro_reset()` is meant to be called on a *valid* game state (equivalent to pressing
  the physical reset button on the console)
- If the core's internal pointers or state machine are corrupted, `retro_reset()` may
  not know how to recover from that

### Evidence

- PicoDrive: `retro_reset()` calls PicoDrive's reset handler which resets CPU registers
  and some state, but does NOT fully re-load the ROM or reinitialize all memory regions
- A hard reinitialize (equivalent to `retro_deinit()` + `retro_init()` + `retro_load_game()`)
  would be needed for a guaranteed clean state, but this is the equivalent of "quit and
  restart the game" in the app

---

## What We Fixed (App-Level)

**Issue #3077** describes the behavior change after a failed save state load (introduced in this PR):

**Before:** Error is shown, emulator unpauses (potentially in corrupted state)

**After:** User is offered:
- **Reset Game** — calls `core.resetEmulation()` (best effort; may not fix core-level corruption)
- **Continue** — existing behavior (unpause and continue)

This is the best we can do without core-level changes.

---

## Known Limitations

1. **`retro_reset()` is not a guaranteed fix** for post-`retro_unserialize()` corruption.
   It is a "soft reset" (hardware reset button equivalent), not a full reinitialization.

2. **Core-specific bugs** in PicoDrive's `retro_reset()` cannot be fixed at the app level
   without modifying upstream libretro-picodrive.

3. **The correct deep fix** would be to implement a "Reload ROM" option that:
   - Unloads the core via `retro_unload_game()` + `retro_deinit()`
   - Re-initializes via `retro_init()` + `retro_load_game()`
   - This is equivalent to quitting and relaunching the game
   - Future work: add a "Restart Game" option to the emulator menu (#TODO)

---

## Recommendations for Future Work

1. **Add "Restart Game" to the RetroMenuView** that fully reinitializes the core
   (unload + reload ROM). This would definitively fix the corrupt-state problem.

2. **Upstream PicoDrive fix:** File an issue in the libretro-picodrive repository
   requesting that `retro_reset()` fully reinitializes state after a failed
   `retro_unserialize()`.

3. **Core error reporting:** When `retro_unserialize()` returns false, cores should
   ideally report whether they left the state valid (so `retro_reset()` is sufficient)
   or corrupted (so a full reinitialize is needed). This is a libretro protocol gap.

---

## Related Files

- `PVCoreBridgeRetro/Sources/PVLibRetro/PVLibRetroCore+Saves.m` — `loadStateFromFileAtPath:`
- `PVCoreBridgeRetro/Sources/PVLibRetro/PVLibRetroCore.m` — `resetEmulation`
- `Cores/PicoDrive/Sources/PVPicoDriveBridge/PVPicoDriveBridge.m` — PicoDrive `resetEmulation`
- `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController+Saves.swift` — load error handling
- `PVUI/Sources/PVUIBase/PVEmulatorVC/RetroMenuView.swift` — Reset Game menu button
