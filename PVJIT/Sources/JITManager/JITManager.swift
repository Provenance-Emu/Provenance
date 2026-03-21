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

    /// Lock protecting `_acquired` for cross-thread access.
    private static let _acquiredLock = NSLock()
    private static var _acquired: Bool = false

    /// Thread-safe snapshot of JIT acquisition state.
    /// Written from the main actor at startup via `hasAcquiredJit`; safe to read
    /// from any thread (libretro callbacks, background queues, etc.) via NSLock.
    public static var acquired: Bool {
        _acquiredLock.withLock { _acquired }
    }

    private var jitType: DOLJitType = .none
    private var auxError: String?
    private var hasAcquiredJit = false {
        didSet {
            if hasAcquiredJit {
                DOLJitManager._acquiredLock.withLock { DOLJitManager._acquired = true }
            }
        }
    }
    private var isDiscoveringAltserver = false
    /// The detected JIT source. Starts as `.none`; updated after acquisition
    /// and refined by UIKit-capable detection (see `JITSourceDetector`).
    private var jitSource: JITSource = .none

    private func hasNativeJitEntitlement() -> Bool {
        if #available(iOS 13.4, tvOS 13.4, *) {
            return HasBooleanEntitlement("com.apple.developer.kernel.allow-jit")
        } else {
            return false
        }
    }

    private init() {}

    public
    func attemptToAcquireJitOnStartup() {
#if targetEnvironment(simulator)
        jitType = .notRestricted
#else
        // iOS 26+ native JIT entitlement — highest priority after simulator.
        // JITAuthorizer is a private/SPI class introduced in iOS 26 that authorizes
        // JIT when the app has `com.apple.developer.kernel.allow-jit` entitlement.
        // TODO: Replace NSClassFromString lookup with a direct import when public API.
        if NSClassFromString("JITAuthorizer") != nil, hasNativeJitEntitlement() {
            jitType = .nativeEntitlement
        }
        // TrollStore installs apps with unrestricted `get-task-allow` entitlement.
        // Detect via known file-system markers left by TrollStore on-device.
        else if isInstalledViaTrollStore() {
            jitType = .trollStore
        }
        else {
#if NONJAILBROKEN
            if #available(iOS 14.5, tvOS 14.5, *) {
                jitType = .debugger
            } else {
                if #available(iOS 14.4, tvOS 14.4, *) {
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
            }
#else // jailbroken
            jitType = .debugger
#endif
        }
#endif // !simulator

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
        case .allowUnsigned, .notRestricted, .nativeEntitlement, .trollStore:
            hasAcquiredJit = true
        case .ptrace:
            SetProcessDebuggedWithPTrace()
            hasAcquiredJit = true
        case .stikDebug, .none:
            // .stikDebug requires explicit call to attemptToAcquireJitByStikDebug().
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

        ServerManager.shared.startDiscovering()

        ServerManager.shared.autoconnect { result in
            ServerManager.shared.stopDiscovering()

            switch result {
            case .failure(let error):
                NotificationCenter.default.post(name: .DOLJitAltJitFailure, object: self, userInfo: [
                    "nserror": error
                ])
                self.isDiscoveringAltserver = false

            case .success(let connection):
                connection.enableUnsignedCodeExecution { execResult in
                    switch execResult {
                    case .success:
                        // Don't post a notification here, since attemptToAcquireJitByWaitingForDebugger
                        // will do it for us.
                        break
                    case .failure(let error):
                        NotificationCenter.default.post(name: .DOLJitAltJitFailure, object: self, userInfo: [
                            "nserror": error
                        ])
                    }

                    connection.disconnect()
                    self.isDiscoveringAltserver = false
                }
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

    /// Asks StikDebug to attach its debugger to the current process via HTTP.
    ///
    /// StikDebug exposes a lightweight HTTP server over its VPN tunnel (similar
    /// to JitStreamer). Calling this method sends a POST request to the StikDebug
    /// attach endpoint. The call completes asynchronously; JIT is available once
    /// `recheckHasAcquiredJit()` returns `true` (or the `DOLJitAcquired`
    /// notification fires from `attemptToAcquireJitByWaitingForDebugger`).
    ///
    /// - Note: The VPN tunnel must be active before calling this method.
    ///         StikDebug uses `10.80.80.2` as its tunnel gateway.
    public
    func attemptToAcquireJitByStikDebug() {
        if jitType != .debugger && jitType != .stikDebug {
            ELOG("StikDebug: unexpected jitType \(jitType)")
            return
        }

        if hasAcquiredJit {
            ILOG("StikDebug: JIT already acquired")
            return
        }

        // StikDebug uses a VPN tunnel with gateway 10.80.80.2 and an HTTP
        // attach endpoint mirroring JitStreamer's protocol.
        let pid = getpid()
        let urlString = "http://10.80.80.2/attach/\(pid)/"
        ILOG("StikDebug: POST \(urlString)")

        guard let url = URL(string: urlString) else {
            ELOG("StikDebug: failed to construct URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data()
        request.timeoutInterval = 10

        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                ELOG("StikDebug: \(error.localizedDescription)")
                return
            }
            if let response = response {
                ILOG("StikDebug: Response: \(response)")
            }
            if let data = data, !data.isEmpty {
                ILOG("StikDebug: \(String(data: data, encoding: .utf8) ?? "")")
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

    // MARK: - iOS 26 W×X Detection

    /// Returns `true` when the current OS enforces Write-XOR-Execute (W×X) page protections.
    ///
    /// iOS 26 introduces the Trusted Execution Monitor (TXM) which prevents a single mapping
    /// from being both writable and executable at the same time.  Dynarec-based cores
    /// (Mupen64Plus, Flycast) must use the dual-mapping shadow-page pattern when this returns
    /// `true`.  See `Scripts/StikDebug/provenance.js` for the BRK #0x69 handler.
    ///
    /// - Note: This check is based on iOS/tvOS 26 availability (`#available(iOS 26, tvOS 26, *)`).
    ///         On the simulator W×X is never enforced.
    public static var isWXEnforced: Bool {
        return _isWXEnforced(isSimulator: {
#if targetEnvironment(simulator)
            return true
#else
            return false
#endif
        }())
    }

    /// Internal helper that makes W×X enforcement logic testable by injecting
    /// the simulator flag.
    ///
    /// - Parameter isSimulator: Whether the code is running under the simulator.
    /// - Returns: `true` if W×X is enforced on the current OS, otherwise `false`.
    static func _isWXEnforced(isSimulator: Bool) -> Bool {
        if isSimulator {
            return false
        }
        if #available(iOS 26, tvOS 26, *) {
            return true
        }
        return false
    }

    // MARK: - File-system JIT Source Detection

    /// Performs lightweight, file-system-only detection of the JIT source.
    /// URL-scheme checks (StikDebug) are handled by `JITSourceDetector` in
    /// the PVJIT target which has access to UIKit.
    private func detectJITSourceFileSystem() -> JITSource {
#if targetEnvironment(simulator)
        return .system
#else
        // iOS 26+ native JIT API — `nativeEntitlement` jitType maps to `.system`.
        // TODO: Replace NSClassFromString lookup with a direct import when the
        //       JITAuthorizer API becomes public (currently private/SPI in iOS 26).
        if jitType == .nativeEntitlement || NSClassFromString("JITAuthorizer") != nil {
            return .system
        }

        // TrollStore installs apps with unrestricted `get-task-allow` entitlement.
        if isInstalledViaTrollStore() {
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

    // MARK: - TrollStore Detection

    /// Returns `true` if **this app** was installed via TrollStore.
    ///
    /// TrollStore grants unrestricted entitlements (including `get-task-allow`)
    /// at install time and leaves identifiable file-system markers on the device.
    /// We combine both checks so that TrollStore being present on the device alone
    /// is not sufficient — the app must also carry `get-task-allow`, which TrollStore
    /// injects but AltStore/App Store builds do not in release configurations.
    public func isInstalledViaTrollStore() -> Bool {
        // 1. Check device-wide TrollStore installation markers.
        let deviceMarkers = [
            "/var/mobile/Library/Application Support/TrollStore",
            "/usr/lib/TrollStore",
            "/var/containers/Bundle/TrollStore",
        ]
        guard deviceMarkers.contains(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return false
        }

        // 2. Verify this binary carries `get-task-allow` (injected by TrollStore at
        //    install time; not present in App Store or AltStore release builds).
        if #available(iOS 13.4, tvOS 13.4, *) {
            return HasBooleanEntitlement("get-task-allow")
        } else {
            return false
        }
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
