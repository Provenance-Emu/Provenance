//
//  JitAcquisitionUtils..swift
//
//
//  Created by Joseph Mattiello on 6/1/24.
//
// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

import Foundation
import DebuggerUtils

@MainActor private var hasJit = false
@MainActor private var hasJitWithPTrace = false
@MainActor private var isArm64e = false
@MainActor private var acquisitionError: DOLJitError = .none
@MainActor private var acquisitionErrorMessage = [CChar](repeating: 0, count: 256)

@MainActor func GetCpuArchitecture() -> Bool {
    guard let gestaltHandle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY) else {
        return false
    }
    defer {
        dlclose(gestaltHandle)
    }

    typealias MGCopyAnswerPtr = @convention(c) (String) -> String

    guard let MGCopyAnswer = dlsym(gestaltHandle, "MGCopyAnswer").assumingMemoryBound(to: MGCopyAnswerPtr.self).pointee as? MGCopyAnswerPtr else {
        return false
    }

    let cpuArchitecture = MGCopyAnswer("k7QIBwZJJOVw+Sej/8h8VA") // "CPUArchitecture"
    isArm64e = cpuArchitecture == "arm64e"

    return true
}

@MainActor func AcquireJitWithAllowUnsigned() -> DOLJitError {
    if !GetCpuArchitecture() {
        SetJitAcquisitionErrorMessage(dlerror())
        return .gestaltFailed
    }

    if !isArm64e {
        return .notArm64e
    }

    if #available(iOS 13.4, *) {
        if !HasValidCodeSignature() {
            return .improperlySigned
        }
    } else {
        // Fallback on earlier versions
        return .none
    }

    // CS_EXECSEG_ALLOW_UNSIGNED will let us have JIT
    // (assuming it's signed correctly)
    return .none
}

@MainActor func AcquireJit() {
    if IsProcessDebugged() {
        hasJit = true
        return
    }

#if targetEnvironment(simulator)
    hasJit = true
    return
#endif

#if NONJAILBROKEN
    if #available(iOS 14.4, *) {
        // "Yes", we do have JIT. At least, we will later when AltServer/Jitterbug/
        // Xcode/etc connnects to us.
        hasJit = true
    } else if #available(iOS 14.2, *) {
        acquisitionError = AcquireJitWithAllowUnsigned()
        if acquisitionError == .none {
            hasJit = true
        }
    } else if #available(iOS 14, *) {
        acquisitionError = .needUpdate
    } else if #available(iOS 13.5, *) {
        SetProcessDebuggedWithPTrace()

        hasJit = true
        hasJitWithPTrace = true
    } else {
        acquisitionError = .needUpdate
    }
#else // jailbroken
    var success = false

    // Check for jailbreakd (Chimera, Electra, Odyssey...)
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: "/var/run/jailbreakd.pid") {
        success = SetProcessDebuggedWithJailbreakd()
        if !success {
            acquisitionError = .jailbreakdFailed
        }
    } else {
        success = SetProcessDebuggedWithDaemon()
        if !success {
            acquisitionError = .csdbgdFailed
        }
    }

    hasJit = success
#endif
}

@MainActor func HasJit() -> Bool {
    return hasJit
}

@MainActor func HasJitWithPTrace() -> Bool {
    return hasJitWithPTrace
}

@MainActor func GetJitAcquisitionError() -> DOLJitError {
    return acquisitionError
}

@MainActor func GetJitAcquisitionErrorMessage() -> String {
    return String(cString: acquisitionErrorMessage)
}

@MainActor func SetJitAcquisitionErrorMessage(_ error: UnsafePointer<CChar>?) {
    if let error = error {
        strncpy(&acquisitionErrorMessage, error, 256)
        acquisitionErrorMessage[255] = 0
    }
}
