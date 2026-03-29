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

    /// Returns `true` if the running binary has the `com.apple.developer.kernel.allow-jit` entitlement.
    ///
    /// - Important: This entitlement is **not** included in App Store builds because Apple does not
    ///   allow it in App Store submissions. It is present only in jailbreak (JB) builds where the
    ///   entitlement can be granted outside of App Store review. App Store users rely on alternative
    ///   JIT acquisition paths (debugger attach, TrollStore, AltJIT, StikDebug, JitStreamer).
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
            // On iOS 26+, JITAuthorizer is the preferred JIT path but requires the
            // `com.apple.developer.kernel.allow-jit` entitlement. If that entitlement
            // is absent (App Store builds, developer builds without it), we fall back
            // to checking CS_DEBUGGED via csops. Xcode's debugger still sets CS_DEBUGGED
            // on iOS 26 for development-signed builds, so this may succeed when running
            // from Xcode. Note: even with JIT acquired, dynarec cores must use the
            // dual-mapping (shadow-page) pattern on iOS 26 due to W×X enforcement.
            // For production App Store builds on iOS 26, JIT is structurally unavailable;
            // performance-sensitive cores (Dolphin, 3DS, Flycast) will run in fallback mode.
            if #available(iOS 26, tvOS 26, *), NSClassFromString("JITAuthorizer") != nil {
                WLOG("JIT: iOS 26 — JITAuthorizer present but 'allow-jit' entitlement absent. "
                    + "Checking CS_DEBUGGED for Xcode/debugger-based JIT. "
                    + "Add com.apple.developer.kernel.allow-jit for reliable iOS 26 JIT.")
            }
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

    // MARK: - Distribution Detection

    /// Returns `true` only when the build was compiled for App Store distribution
    /// **and** is genuinely running as an official App Store install (not sideloaded or resigned).
    ///
    /// GitHub CI produces App Store–flavored builds (`APP_STORE` define) that users can
    /// sideload by resigning the IPA — changing the bundle ID or injecting the
    /// `com.apple.developer.kernel.allow-jit` entitlement in the process.  This function
    /// detects that at runtime so the JIT UI can show sideloading-tool suggestions even
    /// in App Store–compiled builds when the build has clearly been modified.
    ///
    /// Detection heuristics (all must pass to return `true`):
    /// - Compiled with `APP_STORE` define (compile-time guard)
    /// - Bundle ID still has the official `org.provenance-emu.provenance` prefix
    /// - The `com.apple.developer.kernel.allow-jit` entitlement is **absent** (a resigned
    ///   IPA would have added it)
    /// - No `embedded.mobileprovision` present (App Store strips this; sideloaders keep it)
    ///
    /// - Returns: `true` for a genuine App Store install, `false` for any dev / sideload build.
    public static func isGenuinelyAppStoreDistributed() -> Bool {
        #if !APP_STORE
        return false
        #else
        return _cachedIsGenuinelyAppStoreDistributed
        #endif
    }

    #if APP_STORE
    /// Cached once — bundle ID, entitlements, and provisioning profile layout do not change at runtime.
    private static let _cachedIsGenuinelyAppStoreDistributed: Bool = {
        guard let bundleID = Bundle.main.bundleIdentifier,
              bundleID.hasPrefix("org.provenance-emu.provenance") else {
            return false
        }
        if #available(iOS 13.4, tvOS 13.4, *) {
            if HasBooleanEntitlement("com.apple.developer.kernel.allow-jit") {
                return false
            }
        }
        if Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") != nil {
            return false
        }
        return true
    }()
    #endif

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
#if os(iOS) || os(tvOS)
        if #available(iOS 26, tvOS 26, *) {
            return true
        }
#endif
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

// MARK: - C-callable bridge for RetroArch core

/// C-callable wrapper around `DOLJitManager.acquired` for use by the RetroArch
/// bridge (`jit_available()` in `JITSupport.m`).
///
/// The RetroArch core can't import Swift modules directly, so we expose this as
/// a plain C symbol via `@_cdecl`.  The caller should declare it as a weak
/// extern so the call gracefully no-ops when PVJIT isn't linked:
///
/// ```objc
/// extern bool PVJITManagerIsAcquired(void) __attribute__((weak));
/// ```
///
/// - Important: This function only reports the current value of `DOLJitManager.acquired`.
///   It does not attempt to acquire JIT itself and does not guarantee that
///   `DOLJitManager.attemptToAcquireJitOnStartup()` (or any other acquisition path)
///   has already been run. Callers that rely on JIT being available must ensure
///   acquisition has been attempted earlier in the app lifecycle. The `jit_available()`
///   fallback path in `JITSupport.m` handles cases where acquisition hasn't run yet.
@_cdecl("PVJITManagerIsAcquired")
public func PVJITManagerIsAcquired() -> Bool {
    return DOLJitManager.acquired
}

/// C-callable entitlement check for the iOS 26 native JIT path.
///
/// Returns `true` only when `com.apple.developer.kernel.allow-jit` is present
/// **and** set to `true` for the running process (via `SecTaskCopyValueForEntitlement`,
/// with Mach-O signature fallback in `HasBooleanEntitlement`).
///
/// ```objc
/// extern bool PVJITHasNativeJITEntitlement(void) __attribute__((weak));
/// ```
@_cdecl("PVJITHasNativeJITEntitlement")
public func PVJITHasNativeJITEntitlement() -> Bool {
    if #available(iOS 13.4, tvOS 13.4, *) {
        return HasBooleanEntitlement("com.apple.developer.kernel.allow-jit")
    }
    return false
}

/// C-callable check for whether this app was installed via TrollStore.
///
/// Combines device-wide file-system markers with a `get-task-allow` entitlement
/// check (`SecTask` / `HasBooleanEntitlement`) so that TrollStore being present on
/// the device alone is not sufficient — the app must also carry `get-task-allow`.
/// This prevents a false-positive on non-TrollStore builds on TrollStore devices.
///
/// ```objc
/// extern bool PVJITIsInstalledViaTrollStore(void) __attribute__((weak));
/// ```
@_cdecl("PVJITIsInstalledViaTrollStore")
public func PVJITIsInstalledViaTrollStore() -> Bool {
    let deviceMarkers = [
        "/var/mobile/Library/Application Support/TrollStore",
        "/usr/lib/TrollStore",
        "/var/containers/Bundle/TrollStore",
    ]
    guard deviceMarkers.contains(where: { FileManager.default.fileExists(atPath: $0) }) else {
        return false
    }
    if #available(iOS 13.4, tvOS 13.4, *) {
        return HasBooleanEntitlement("get-task-allow")
    }
    return false
}
