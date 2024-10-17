//
//  DebuggerUtils.swift
//
//
//  Created by Joseph Mattiello on 6/1/24.
//
// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

import Foundation
import System
import DebuggerUtils

let CS_OPS_STATUS = 0
let CS_DEBUGGED = 0x10000000
let PT_TRACEME = 0
let FLAG_PLATFORMIZE = 1 << 1

func WaitUntilProcessDebugged(timeout: Int) -> Bool {
    var timeLeft = timeout
    var isDebugged = false

    while timeLeft > 0 {
        isDebugged = IsProcessDebugged()
        if isDebugged {
            break
        }

        timeLeft -= 1

        usleep(1000000)
    }

    return isDebugged
}

func SetProcessDebuggedWithDaemon() -> Bool {
    var processID = getpid()
    let data = Data(bytes: &processID, count: MemoryLayout<Int32>.size)

    guard let port = CFMessagePortCreateRemote(kCFAllocatorDefault, "me.oatmealdome.csdbgd-port" as CFString) else {
        DOLJitManager.shared.setAuxiliaryError("Unable to open port")
        return false
    }

    let ret = CFMessagePortSendRequest(port, 1, data as CFData, 1000, 0, nil, nil)
    if ret != kCFMessagePortSuccess {
        DOLJitManager.shared.setAuxiliaryError("Failed to send message through port")
        return false
    }

    let success = WaitUntilProcessDebugged(timeout: 5)
    if !success {
        DOLJitManager.shared.setAuxiliaryError("csdbgd timed out")
    }

    return success
}

func LoadLibJailbreak() -> UnsafeMutableRawPointer? {
    if let dylibHandle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY) {
        return dylibHandle
    }

    let internalPath = Bundle.main.bundlePath + "/Frameworks/libjailbreak.dylib"
    return dlopen(internalPath, RTLD_LAZY)
}

func SetProcessDebuggedWithJailbreakd() -> Bool {
    guard let dylibHandle = LoadLibJailbreak() else {
        let errorString: String? = String(cString: dlerror())
        DOLJitManager.shared.setAuxiliaryError(errorString)
        return false
    }

    guard let ptr = dlsym(dylibHandle, "jb_oneshot_entitle_now") else {
        let errorString: String? = String(cString: dlerror())
        DOLJitManager.shared.setAuxiliaryError(errorString)
        dlclose(dylibHandle)
        return false
    }

    let entitleNowPtr = unsafeBitCast(ptr, to: (@convention(c) (Int32, UInt32) -> Int32).self)

    entitleNowPtr(getpid(), UInt32(FLAG_PLATFORMIZE))

    dlclose(dylibHandle)

    return true
}
