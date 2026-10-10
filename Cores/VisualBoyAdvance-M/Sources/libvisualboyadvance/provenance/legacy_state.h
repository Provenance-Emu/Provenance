// Provenance: loading save states written by the VBA-M 1.8-era core that
// Provenance shipped before moving to the 2.x submodule.
//
// Both cores write gzip "SGM" states with SAVE_GAME_VERSION 10, but the
// layout differs: the cheat list grew from 100 to MAX_CHEATS entries.
// Everything before the cheat block (CPU, memory, I/O, EEPROM/flash, sound)
// and the RTC block after it are byte-identical. 2.x's reader trusts the
// version number, so an unconverted 1.8 state would load with the RTC state
// swallowed into the cheat list. LoadState() detects legacy states by their
// exact uncompressed length and upgrades them first; anything matching
// neither layout is refused.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace pvvba {

enum class StateLoadResult {
    Loaded,          // 2.x state, loaded as is
    LoadedLegacy,    // 1.8 state, upgraded and loaded
    ReadFailed,      // file unreadable, or the layout probe failed
    Incompatible,    // neither layout; nothing was loaded
    CoreRejected,    // CPUReadState refused it (wrong game, BIOS mismatch...)
};

// Upgrades an uncompressed 1.8 state to the 2.x layout by zero-filling the
// new cheat slots, which sit just before the last `tailLength` bytes.
// Returns false, leaving `data` untouched, unless it is exactly the legacy
// counterpart of a `currentLength`-byte 2.x state.
bool UpgradeLegacyState(std::vector<uint8_t>& data, size_t currentLength, size_t tailLength);

// Loads a GBA state for the running game. `scratchDirectory` receives
// short-lived temp files. After LoadedLegacy the caller must restore
// coreOptions.saveType: 1.8 stored its own numbering in that field.
StateLoadResult LoadState(const std::string& path, const std::string& scratchDirectory);

}  // namespace pvvba
