// PVRetroArchCoreCapabilities.m — Dynamic libretro capability queries
//
// Implements the helpers declared in PVRetroArchCoreCapabilities.h by reading
// live RetroArch runloop state that the core populated during initialization.

#import <Foundation/Foundation.h>
#include "PVRetroArchCoreCapabilities.h"
#import "PVRetroArchCoreBridge.h"

/* RetroArch internals */
#include "libretro-common/include/libretro.h"
#include "../../retroarch.h"

// ---------------------------------------------------------------------------
// Core game-loaded callback
// ---------------------------------------------------------------------------
void pv_notify_core_game_loaded(void) {
    PVRetroArchCoreBridge *bridge = _current;
    if (!bridge) return;
    if (![bridge respondsToSelector:@selector(onCoreGameLoaded)]) return;
    void (^callback)(void) = bridge.onCoreGameLoaded;
    if (callback) {
        bridge.onCoreGameLoaded = nil;
        dispatch_async(dispatch_get_main_queue(), callback);
    }
}

// ---------------------------------------------------------------------------
// RETRO_DEVICE_MOUSE detection
// ---------------------------------------------------------------------------
// Walk sys_info->ports.data, which is populated by the core's
// RETRO_ENVIRONMENT_SET_CONTROLLER_INFO callback.  Each entry lists the device
// types supported on that port; we look for RETRO_DEVICE_MOUSE (id == 2).
bool pv_core_declares_mouse_device(void) {
    rarch_system_info_t *sys_info = &runloop_state_get_ptr()->system;
    if (!sys_info || !sys_info->ports.data || sys_info->ports.size == 0)
        return false;

    for (unsigned port = 0; port < sys_info->ports.size; port++) {
        const struct retro_controller_info *info = &sys_info->ports.data[port];
        if (!info->types)
            continue;
        for (unsigned j = 0; j < info->num_types; j++) {
            // Mask off any sub-class bits before comparing.
            if ((info->types[j].id & RETRO_DEVICE_MASK) == RETRO_DEVICE_MOUSE)
                return true;
        }
    }
    return false;
}

// ---------------------------------------------------------------------------
// L2/R2 native trigger detection
// ---------------------------------------------------------------------------
// sys_info->input_desc_btn[port][id] is set to a non-NULL description string
// when the core calls RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS and declares that
// button for the given port.  We check port 0 for L2 and R2.
bool pv_core_declares_l2r2_triggers(void) {
    rarch_system_info_t *sys_info = &runloop_state_get_ptr()->system;
    if (!sys_info)
        return false;

    // sys_info->input_desc_btn is a fixed 2-D array; a non-NULL entry means the
    // core explicitly named that button in its input descriptor list.
    const char *l2 = sys_info->input_desc_btn[0][RETRO_DEVICE_ID_JOYPAD_L2];
    const char *r2 = sys_info->input_desc_btn[0][RETRO_DEVICE_ID_JOYPAD_R2];
    return (l2 != NULL && l2[0] != '\0') || (r2 != NULL && r2[0] != '\0');
}

// ---------------------------------------------------------------------------
// Port device type configuration
// ---------------------------------------------------------------------------
void pv_core_set_controller_port_device(unsigned port, unsigned device) {
    retro_ctx_controller_info_t pad = { .port = port, .device = device };
    core_set_controller_port_device(&pad);
}

// ---------------------------------------------------------------------------
// RETRO_DEVICE_LIGHTGUN detection
// ---------------------------------------------------------------------------
bool pv_core_declares_lightgun_device(void) {
    rarch_system_info_t *sys_info = &runloop_state_get_ptr()->system;
    if (!sys_info || !sys_info->ports.data || sys_info->ports.size == 0)
        return false;

    for (unsigned port = 0; port < sys_info->ports.size; port++) {
        const struct retro_controller_info *info = &sys_info->ports.data[port];
        if (!info->types)
            continue;
        for (unsigned j = 0; j < info->num_types; j++) {
            if ((info->types[j].id & RETRO_DEVICE_MASK) == RETRO_DEVICE_LIGHTGUN)
                return true;
        }
    }
    return false;
}

// ---------------------------------------------------------------------------
// RETRO_DEVICE_KEYBOARD detection
// ---------------------------------------------------------------------------
bool pv_core_declares_keyboard_device(void) {
    rarch_system_info_t *sys_info = &runloop_state_get_ptr()->system;
    if (!sys_info || !sys_info->ports.data || sys_info->ports.size == 0)
        return false;

    for (unsigned port = 0; port < sys_info->ports.size; port++) {
        const struct retro_controller_info *info = &sys_info->ports.data[port];
        if (!info->types)
            continue;
        for (unsigned j = 0; j < info->num_types; j++) {
            if ((info->types[j].id & RETRO_DEVICE_MASK) == RETRO_DEVICE_KEYBOARD)
                return true;
        }
    }
    return false;
}
