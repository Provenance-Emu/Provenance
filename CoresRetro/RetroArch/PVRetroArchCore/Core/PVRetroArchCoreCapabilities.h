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
// Functions return false until the core has reported controller/input descriptors.

#pragma once
#include <stdbool.h>
#include <stdint.h>

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
// GameCube, etc.) are expected to declare these labels.  Cores for simpler
// controllers (NES, SNES 2‑button, Game Boy) typically leave them NULL.
//
// Returns false in both of the following cases:
//   - The core never called SET_INPUT_DESCRIPTORS at all; or
//   - The core did call SET_INPUT_DESCRIPTORS, but did not provide L2/R2
//     labels for port 0.
//
// Callers that need to distinguish "no descriptors declared" from "descriptors
// declared but no L2/R2 buttons" must use additional context or a separate
// helper; this function only answers whether L2/R2 triggers are available.
bool pv_core_declares_l2r2_triggers(void);

// ---------------------------------------------------------------------------
// Convenience: RETRO_DEVICE_KEYBOARD support
// ---------------------------------------------------------------------------
// Returns true if the loaded core declared RETRO_DEVICE_KEYBOARD as a
// supported device type on ANY controller port via
// RETRO_ENVIRONMENT_SET_CONTROLLER_INFO.
bool pv_core_declares_keyboard_device(void);

// ---------------------------------------------------------------------------
// RETRO_DEVICE_LIGHTGUN detection
// ---------------------------------------------------------------------------
// Returns true if the loaded core declared RETRO_DEVICE_LIGHTGUN (id == 4)
// as a supported device type on ANY controller port via
// RETRO_ENVIRONMENT_SET_CONTROLLER_INFO.
bool pv_core_declares_lightgun_device(void);

// ---------------------------------------------------------------------------
// Light Gun setters — write normalised state that cocoa_input_state serves
// to the libretro core via RETRO_DEVICE_LIGHTGUN queries.
//
// x, y: screen-space coordinates in the range [-0x7FFF, +0x7FFF]
//       (same scale as RETRO_DEVICE_ID_LIGHTGUN_SCREEN_X/Y).
// offscreen: true when the gun is pointed away from the screen.
// ---------------------------------------------------------------------------
void pv_lightgun_set_position(int16_t x, int16_t y, bool offscreen);
void pv_lightgun_set_trigger(bool down);
void pv_lightgun_set_reload(bool down);
void pv_lightgun_set_aux_a(bool down);
void pv_lightgun_set_aux_b(bool down);
void pv_lightgun_set_start(bool down);
void pv_lightgun_set_select(bool down);

// ---------------------------------------------------------------------------
// Port device type configuration
// ---------------------------------------------------------------------------
// Calls RetroArch's core_set_controller_port_device() to set the libretro
// device type on a specific controller port.  Must be called AFTER
// retro_load_game (i.e. after the core has initialised its port table).
//
// Common device type values (from libretro.h):
//   RETRO_DEVICE_NONE    = 0
//   RETRO_DEVICE_JOYPAD  = 1
//   RETRO_DEVICE_MOUSE   = 2
void pv_core_set_controller_port_device(unsigned port, unsigned device);

#ifdef __cplusplus
}
#endif
