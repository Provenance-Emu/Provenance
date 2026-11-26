//
//  AppDistribution.swift
//  JITManager
//
//  How this install reached the device, and what JIT UI it may show.
//

import Foundation

/// How the running app was installed.
///
/// Every shipping scheme is compiled the same way, so this can only be decided at
/// run time, from what the install looks like on disk.
public enum AppDistribution: String, Sendable, CaseIterable {
    /// Running in the iOS or tvOS simulator.
    case simulator
    /// Signed with a development profile (`get-task-allow`): Xcode, AltStore, SideStore.
    case development
    /// Re-signed or distributed outside the store: ad hoc or enterprise profile, or a changed bundle id.
    case sideloaded
    /// A store-signed or fake-signed build on a device with a jailbreak or TrollStore.
    case jailbroken
    /// Installed from TestFlight on a stock device.
    case testFlight
    /// Installed from the App Store on a stock device.
    case appStore

    /// `true` for TestFlight and App Store installs on a stock device, where nothing
    /// the user can do enables JIT.
    public var isStoreInstall: Bool {
        self == .testFlight || self == .appStore
    }
}

/// The facts ``AppDistribution/resolve(_:)`` decides from. Injected in tests.
public struct AppDistributionInputs: Sendable, Equatable {
    public var isSimulator: Bool
    public var bundleIdentifier: String?
    /// `embedded.mobileprovision` is in the app bundle. The store strips it from
    /// TestFlight and App Store installs; every other signed install keeps it.
    public var hasEmbeddedProvisioningProfile: Bool
    /// The embedded profile grants `get-task-allow` (a development profile).
    public var profileAllowsDebugging: Bool
    /// Last path component of `Bundle.appStoreReceiptURL`: `sandboxReceipt` on TestFlight.
    public var receiptFileName: String?
    /// A jailbreak or TrollStore left its files on the device.
    public var hasJailbreakMarkers: Bool

    public init(isSimulator: Bool = false,
                bundleIdentifier: String?,
                hasEmbeddedProvisioningProfile: Bool,
                profileAllowsDebugging: Bool = false,
                receiptFileName: String?,
                hasJailbreakMarkers: Bool = false) {
        self.isSimulator = isSimulator
        self.bundleIdentifier = bundleIdentifier
        self.hasEmbeddedProvisioningProfile = hasEmbeddedProvisioningProfile
        self.profileAllowsDebugging = profileAllowsDebugging
        self.receiptFileName = receiptFileName
        self.hasJailbreakMarkers = hasJailbreakMarkers
    }
}

public extension AppDistribution {
    /// Bundle ids the store builds ship with (`.alpha`, extensions and Lite share the prefix).
    static let officialBundleIdentifierPrefix = "org.provenance-emu.provenance"
    /// Receipt file name of a TestFlight install.
    static let sandboxReceiptFileName = "sandboxReceipt"

    /// Files a jailbreak or TrollStore leaves on the device.
    static let jailbreakMarkerPaths = [
        "/var/mobile/Library/Application Support/TrollStore",
        "/usr/lib/TrollStore",
        "/var/containers/Bundle/TrollStore",
        "/var/jb",
        "/var/run/jailbreakd.pid",
        "/Applications/Sileo.app",
        "/Applications/Cydia.app"
    ]

    /// Pure decision. The order matters: a provisioning profile or a foreign bundle id
    /// proves the build was not installed by the store, whatever its receipt says.
    static func resolve(_ inputs: AppDistributionInputs) -> AppDistribution {
        if inputs.isSimulator { return .simulator }
        guard let bundleID = inputs.bundleIdentifier,
              bundleID.hasPrefix(officialBundleIdentifierPrefix) else {
            return .sideloaded
        }
        if inputs.hasEmbeddedProvisioningProfile {
            return inputs.profileAllowsDebugging ? .development : .sideloaded
        }
        if inputs.hasJailbreakMarkers { return .jailbroken }
        return inputs.receiptFileName == sandboxReceiptFileName ? .testFlight : .appStore
    }

    /// This install's distribution. Decided once: none of the inputs change while the app runs.
    static let current: AppDistribution = resolve(currentInputs)

    /// The facts ``current`` was decided from, read once at first use.
    static let currentInputs: AppDistributionInputs = .current()

    /// Whether the store installed this build and its purchase rules apply. Unlike
    /// ``isStoreInstall`` this ignores jailbreak markers: a jailbreak makes JIT
    /// possible, it does not make an App Store install a sideload.
    static func isAppStorePurchaseInstall(_ inputs: AppDistributionInputs) -> Bool {
        var stock = inputs
        stock.hasJailbreakMarkers = false
        return resolve(stock) == .appStore
    }
}

public extension AppDistributionInputs {
    /// Reads the real install. Never parses the Mach-O code signature, which crashed
    /// on some store-signed binaries (0e65b6b7ab).
    static func current(bundle: Bundle = .main, fileManager: FileManager = .default) -> AppDistributionInputs {
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        let hasProfile = bundle.url(forResource: "embedded", withExtension: "mobileprovision") != nil
        let allowsDebugging = hasProfile
            && entitlementPlistIndicatesEnabled(entitlementsFromEmbeddedMobileProvision(), key: "get-task-allow")
        return AppDistributionInputs(
            isSimulator: isSimulator,
            bundleIdentifier: bundle.bundleIdentifier,
            hasEmbeddedProvisioningProfile: hasProfile,
            profileAllowsDebugging: allowsDebugging,
            receiptFileName: bundle.appStoreReceiptURL?.lastPathComponent,
            hasJailbreakMarkers: AppDistribution.jailbreakMarkerPaths.contains { fileManager.fileExists(atPath: $0) }
        )
    }
}

// MARK: - JIT UI gate

/// The one gate every JIT surface asks: toasts, the pause-menu JIT entry, the status
/// light and pill, the per-game JIT preference, and the "enable JIT" guidance.
public struct JITUIPolicy: Sendable, Equatable {
    public let distribution: AppDistribution
    /// JIT is already on (a debugger or helper attached before or after launch).
    public let jitAcquired: Bool
    /// The OS refuses writable-and-executable pages (iOS and tvOS 26 and later).
    public let isWXEnforced: Bool

    public init(distribution: AppDistribution, jitAcquired: Bool, isWXEnforced: Bool) {
        self.distribution = distribution
        self.jitAcquired = jitAcquired
        self.isWXEnforced = isWXEnforced
    }

    /// Whether any JIT status or notice may be shown. A TestFlight or App Store
    /// install on a stock device shows none, unless JIT is in fact on.
    public var showsJITUI: Bool {
        jitAcquired || !distribution.isStoreInstall
    }

    /// Whether copy may name sideloading tools (AltStore, SideStore, StikDebug).
    public var mayNameSideloadingTools: Bool {
        !distribution.isStoreInstall
    }

    /// Whether an "enable JIT" action can do anything on this install.
    public var offersJITEnable: Bool {
        !jitAcquired && !distribution.isStoreInstall && !isWXEnforced
    }
}

public extension DOLJitManager {
    /// The JIT UI gate for this install, with the current acquisition state.
    static var uiPolicy: JITUIPolicy {
        JITUIPolicy(distribution: .current, jitAcquired: acquired, isWXEnforced: isWXEnforced)
    }
}
