// PVRetroArchCoreCapabilities.h — Dynamic libretro capability queries
//
// Provides C helper functions that inspect live RetroArch runloop state to
// determine what device types and input bindings the currently-loaded core
// declared at startup.  These replace brittle systemIdentifier/coreIdentifier
// string-matching checks with data the core itself reported.
//
// All functions are safe to call from both C and Objective-C translation units
// that already include retroarch.h.
//
// Availability: populated only AFTER core init (retro_init / retro_load_game).
// Return values are undefined before the core has been loaded.

#pragma once
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// RETRO_DEVICE_MOUSE detection
// ---------------------------------------------------------------------------
// Returns true if the loaded core declared RETRO_DEVICE_MOUSE as a supported
// device type on ANY controller port via RETRO_ENVIRONMENT_SET_CONTROLLER_INFO.
//
// Cores like Hatari (Atari ST) and PrBoom (Doom) expose RETRO_DEVICE_MOUSE,
// meaning they expect relative mouse_rel_x/y deltas.  DOSBox-Pure uses
// RETRO_DEVICE_POINTER (absolute window coordinates) and will NOT have
// RETRO_DEVICE_MOUSE in its port descriptor list.
//
// Returns false if the core never called SET_CONTROLLER_INFO (ports.size == 0),
// which is the case for many cores that don't offer multiple device options.
bool pv_core_declares_mouse_device(void);

// ---------------------------------------------------------------------------
// L2/R2 native trigger detection
// ---------------------------------------------------------------------------
// Returns true if the loaded core explicitly mapped RETRO_DEVICE_ID_JOYPAD_L2
// or RETRO_DEVICE_ID_JOYPAD_R2 to a named button via
// RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS on port 0.
//
// Cores for controllers with physical L2/R2 buttons (PS1, Saturn, N64,
// GameCube, etc.) always declare these labels.  Cores for simpler controllers
// (NES, SNES 2-button, Game Boy) typically leave them NULL.
//
// Returns false if the core never called SET_INPUT_DESCRIPTORS (in which case
// the caller should fall back to the static system-ID list).
bool pv_core_declares_l2r2_triggers(void);

// ---------------------------------------------------------------------------
// Convenience: RETRO_DEVICE_KEYBOARD support
// ---------------------------------------------------------------------------
// Returns true if port 0 of the loaded core declared RETRO_DEVICE_KEYBOARD as
// a supported device type.
bool pv_core_declares_keyboard_device(void);

#ifdef __cplusplus
}
#endif
