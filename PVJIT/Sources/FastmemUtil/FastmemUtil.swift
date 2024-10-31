//
//  FastmemUtil.swift
//  
//
//  Created by Joseph Mattiello on 6/1/24.
//
// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

import Foundation
@_exported import Darwin.Mach

public
enum DOLFastmemType: UInt, Sendable {
    case none
    case proper
    case hacky
}

public let fastmemType: DOLFastmemType = {

    var task: mach_port_t = mach_task_self_

    func canAllocateVirtualMemory(memorySize: UInt) -> Bool {
        var address: vm_address_t = 0
        let retval = vm_allocate(task, &address, vm_size_t(memorySize), VM_FLAGS_ANYWHERE)

        if retval == KERN_SUCCESS {
            vm_deallocate(task, address, vm_size_t(memorySize))
            return true
        }

        return false
    }

    if canAllocateVirtualMemory(memorySize: 0x400000000) {
        return .proper
    } else if canAllocateVirtualMemory(memorySize: 0x80000000) {
        // hacky fastmem can be used on devices with 4GB+ of RAM
        return .hacky
    } else {
        return .none
    }
}()

public let canEnableFastmem: Bool = {
    switch fastmemType {
    case .proper, .hacky: return true
    case .none: return false
    }
}()
