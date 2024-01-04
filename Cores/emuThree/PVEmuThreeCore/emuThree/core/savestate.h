// Copyright 2020 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <vector>
#include "common/common_types.h"
#include <mach/mach.h>
#include <mach/vm_map.h>

namespace Core {

struct SaveStateInfo {
    u32 slot;
    u64 time;
    enum class ValidationStatus {
        OK,
        RevisionDismatch,
    } status;
};

constexpr u32 SaveStateSlotCount = 10; // Maximum count of savestate slots

static vm_address_t save_addr = 0; // compressed save file (max alloc 88mb)
constexpr size_t size  =  88000000;

static vm_address_t save_addr2 = 0; // uncompressed save file (max alloc 512mb)
constexpr size_t size2 = 512000000;
std::vector<SaveStateInfo> ListSaveStates(u64 program_id);
bool InitMem();
void SaveState(std::string path, u64 _title_id);
void LoadState(std::string path);
void CleanState();
} // namespace Core
