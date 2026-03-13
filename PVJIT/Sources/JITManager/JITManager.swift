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
    /// The detected JIT source. Starts as `.none`; updated after acquisition
    /// and refined by UIKit-capable detection (see `JITSourceDetector`).
    private var jitSource: JITSource = .none

    private init() {}

    public
    func attemptToAcquireJitOnStartup() {
#if targetEnvironment(simulator)
        jitType = .notRestricted
#elseif NONJAILBROKEN
        if #available(iOS 14.5, tvOS 14.5, *) {
            jitType = .debugger
        } else if #available(iOS 14.4, tvOS 14.4, *) {
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
        } else if #available(iOS 14.2, tvOS 14.2, *) {
            if canAcquireJitByUnsigned() {
                jitType = .allowUnsigned
            } else {
                jitType = .debugger
            }
        } else if #available(iOS 14.0, tvOS 14.0, *) {
            jitType = .debugger
        } else if #available(iOS 13.5, tvOS 13.4, *) {
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

        // Perform file-system-only JIT source detection (UIKit checks are done
        // by JITSourceDetector in the PVJIT target and fed in via setJITSource).
        if hasAcquiredJit {
            jitSource = detectJITSourceFileSystem()
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

    /// Returns the currently detected JIT source.
    public func getJITSource() -> JITSource {
        return jitSource
    }

    /// Allows the UIKit-capable layer (`JITSourceDetector`) to refine the
    /// detected source after URL-scheme checks complete.
    public func setJITSource(_ source: JITSource) {
        jitSource = source
    }

    // MARK: - File-system JIT Source Detection

    /// Performs lightweight, file-system-only detection of the JIT source.
    /// URL-scheme checks (StikDebug) are handled by `JITSourceDetector` in
    /// the PVJIT target which has access to UIKit.
    private func detectJITSourceFileSystem() -> JITSource {
#if targetEnvironment(simulator)
        return .system
#else
        // iOS 26+ native JIT API — check for the JITAuthorizer Objective-C class.
        // TODO: Replace NSClassFromString lookup with a direct import when the
        //       JITAuthorizer API becomes public (currently private/SPI in iOS 26).
        if NSClassFromString("JITAuthorizer") != nil {
            return .system
        }

        // TrollStore leaves a known support-directory marker on-device.
        let trollStorePaths = [
            "/var/mobile/Library/Application Support/TrollStore",
            "/usr/lib/TrollStore",
            "/var/containers/Bundle/TrollStore",
        ]
        if trollStorePaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
            return .trollStore
        }

        // Jailbroken / developer-provisioned builds that acquire JIT via a
        // system daemon (jailbreakd) are treated as "system" since there is
        // no specific third-party app involved.
#if !NONJAILBROKEN
        return .system
#else
        // Non-jailbroken; source will be refined by JITSourceDetector (UIKit layer).
        return .unknown
#endif
#endif
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

        if #available(iOS 13.4, tvOS 13.4, *) {
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
