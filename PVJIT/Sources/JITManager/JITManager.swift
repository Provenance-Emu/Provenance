//
//  JITManager.swift
//
//
//  Created by Joseph Mattiello on 6/1/24.
//

// Copyright 2021 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

import Foundation
import PVLogging
import DebuggerUtils

#if _USE_ALTKIT
import SideKit
#endif

public
extension Notification.Name {
    static let DOLJitAcquired = Notification.Name("org.provenance-emu.provenance.jit-acquired")
    static let DOLJitAltJitFailure = Notification.Name("org.provenance-emu.provenance.jit-altjit-failure")
}

public final class DOLJitManager {

    @MainActor public static let shared = DOLJitManager()

    private var jitType: DOLJitType = .none
    private var auxError: String?
    private var hasAcquiredJit = false
    private var isDiscoveringAltserver = false

    private init() {}

    public
    func attemptToAcquireJitOnStartup() {
#if targetEnvironment(simulator)
        jitType = .notRestricted
#elseif NONJAILBROKEN
        if #available(iOS 14.5, *) {
            jitType = .debugger
        } else if #available(iOS 14.4, *) {
            var size = 0
            sysctlbyname("kern.osversion", nil, &size, nil, 0)
            var buildString = [CChar](repeating: 0, count: size)
            sysctlbyname("kern.osversion", &buildString, &size, nil, 0)
            let buildStr = String(cString: buildString)

            if buildStr == "18D5030e" && canAcquireJitByUnsigned() {
                jitType = .allowUnsigned
            } else {
                jitType = .debugger
            }
        } else if #available(iOS 14.2, *) {
            if canAcquireJitByUnsigned() {
                jitType = .allowUnsigned
            } else {
                jitType = .debugger
            }
        } else if #available(iOS 14, *) {
            jitType = .debugger
        } else if #available(iOS 13.5, *) {
            jitType = .ptrace
        } else {
            jitType = .debugger
        }
#else // jailbroken
        jitType = .debugger
#endif

        switch jitType {
        case .debugger:
#if NONJAILBROKEN
            hasAcquiredJit = IsProcessDebugged()
#else
            if FileManager.default.fileExists(atPath: "/var/run/jailbreakd.pid") {
                hasAcquiredJit = SetProcessDebuggedWithJailbreakd()
            } else {
                hasAcquiredJit = SetProcessDebuggedWithDaemon()
            }
#endif
        case .allowUnsigned, .notRestricted:
            hasAcquiredJit = true
        case .ptrace:
            SetProcessDebuggedWithPTrace()
            hasAcquiredJit = true
        case .none:
            break
        }
    }

    public
    func recheckHasAcquiredJit() {
        if hasAcquiredJit {
            return
        }

#if NONJAILBROKEN
        if jitType == .debugger {
            hasAcquiredJit = IsProcessDebugged()
        }
#endif
    }

    public
    func attemptToAcquireJitByWaitingForDebugger(using token: DOLCancellationToken) {
        if jitType != .debugger {
            return
        }

        if hasAcquiredJit {
            return
        }

        DispatchQueue.global(qos: .userInteractive).async {
            while !IsProcessDebugged() {
                if token.isCancelled() {
                    return
                }
                sleep(1)
            }

            self.hasAcquiredJit = true

            NotificationCenter.default.post(name: Notification.Name.DOLJitAcquired, object: self)
        }
    }

    public
    func attemptToAcquireJitByAltJIT() {
#if _USE_ALTKIT
        if jitType != .debugger {
            return
        }
        if hasAcquiredJit {
            return
        }

        if isDiscoveringAltserver {
            return
        }

        isDiscoveringAltserver = true

        ALTServerManager.shared.startDiscovering()

        ALTServerManager.shared.autoconnect { connection, error in
            ALTServerManager.shared.stopDiscovering()

            if let error = error {
                NotificationCenter.default.post(name: Notification.Name(rawValue: DOLJitAltJitFailureNotification), object: self, userInfo: [
                    "nserror": error
                ])

                self.isDiscoveringAltserver = false

                return
            }

            connection?.enableUnsignedCodeExecution { success, error in
                if success {
                    // Don't post a notification here, since attemptToAcquireJitByWaitingForDebugger
                    // will do it for us.
                } else if let error = error {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: DOLJitAltJitFailureNotification), object: self, userInfo: [
                        "nserror": error
                    ])
                }

                connection?.disconnect()

                self.isDiscoveringAltserver = false
            }
        }
#endif
    }

    public
    func attemptToAcquireJitByJitStreamer() {
        if jitType != .debugger {
            ELOG("self.jitType != .debugger. Is \(jitType)")
            return
        }

        if hasAcquiredJit {
            ILOG("hasAcquiredJit == true")
            return
        }

        let urlString = "http://69.69.0.1/attach/\(getpid())/"
        ILOG("JIT: URL <\(urlString)>")

        guard let url = URL(string: urlString) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "".data(using: .utf8)

        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                ELOG("JIT: \(error.localizedDescription)")
                return
            }
            if let response = response {
                ILOG("JIT: Response: \(response)")
            }
            if let data = data, !data.isEmpty {
                let dataString = String(data: data, encoding: .utf8)
                ILOG("JIT: \(dataString ?? "")")
            }
        }
        dataTask.resume()
    }

    public
    func getJitType() -> DOLJitType {
        return jitType
    }

    public
    func appHasAcquiredJit() -> Bool {
        return hasAcquiredJit
    }

    public
    func setAuxiliaryError(_ error: String?) {
        auxError = error
    }

    public
    func getAuxiliaryError() -> String? {
        return auxError
    }

    private func getCpuArchitecture() -> String? {
        guard let gestaltHandle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY) else {
            return nil
        }
        defer {
            dlclose(gestaltHandle)
        }

        typealias MGCopyAnswerPtr = @convention(c) (String) -> String

        guard let MGCopyAnswer = dlsym(gestaltHandle, "MGCopyAnswer").assumingMemoryBound(to: MGCopyAnswerPtr.self).pointee as? MGCopyAnswerPtr else {
            return nil
        }

        let cpuArchitecture = MGCopyAnswer("k7QIBwZJJOVw+Sej/8h8VA") // "CPUArchitecture"

        return cpuArchitecture
    }

    private func canAcquireJitByUnsigned() -> Bool {
        guard let cpuArchitecture = getCpuArchitecture() else {
            setAuxiliaryError("CPU architecture check failed.")
            return false
        }

        if cpuArchitecture != "arm64e" {
            return false
        }

        if #available(iOS 13.4, *) {
            if !HasValidCodeSignature() {
                return false
            }
        } else {
            // Fallback on earlier versions
            return false
        }

        return true
    }
}
