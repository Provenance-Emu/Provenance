import Foundation
import PVCoreBridge
import PVEmulatorCore
import PVLogging
import PVSupport

enum PVAzaharCoreError {
    static let domain = "PVAzaharCore"
    static let bootFailed = 1
}

@objc @objcMembers
public final class PVAzaharCore: PVEmulatorCore, @unchecked Sendable {
    /// Name of the Azahar user directory under Documents; read by `PVAzaharCoreBridge.mm` too.
    public static let userDirectoryName = PVAzaharDataMigrator.userDirectoryName

    let _bridge: PVAzaharCoreBridge = .init()

    #if os(tvOS)
    public override var supportsSkins: Bool { false }
    #else
    public override var supportsSkins: Bool { true }
    #endif
    public override var requiresExplicitSkinSelection: Bool { false }
    public override var supportsFilters: Bool { false }
    public override var supportsAudioVisualizer: Bool { false }
    public override var jitRequirement: PVJITRequirement { .automaticWithFallback }

    public required init() {
        super.init()
        guard let objcBridge = _bridge as? any ObjCBridgedCoreBridge else {
            fatalError("PVAzaharCoreBridge must conform to ObjCBridgedCoreBridge")
        }
        self.bridge = objcBridge
        // Load runs on the bridge's emulation thread, so the host only learns the outcome from these.
        _bridge.onEmulationStarted = { [weak self] in
            MainActor.assumeIsolated { self?.emulationDidStart() }
        }
        _bridge.onEmulationFailed = { [weak self] message in
            guard let self else { return }
            NotificationCenter.default.post(
                name: .PVEmulatorCoreDidFailToStart,
                object: nil,
                userInfo: [
                    PVEmulatorCoreDidFailToStartUserInfoKey.error: NSError(
                        domain: PVAzaharCoreError.domain,
                        code: PVAzaharCoreError.bootFailed,
                        userInfo: [NSLocalizedDescriptionKey: message]),
                    PVEmulatorCoreDidFailToStartUserInfoKey.coreIdentifier: self.coreIdentifier ?? ""
                ]
            )
            MainActor.assumeIsolated { self.emulationDidFailToStart() }
        }
    }

    public override func loadFile(atPath path: String) throws {
        Self.migrateEmuThreeDataIfNeeded()
        PVAzaharCoreOptions.apply(to: _bridge)
        try super.loadFile(atPath: path)
    }
}

extension PVAzaharCore {
    /// With emuThreeDS gone nothing else can claim its data, so bring it over before azahar picks its user path.
    fileprivate static func migrateEmuThreeDataIfNeeded() {
        guard !PVAzaharDataMigrator.emuThreeCoreIsPresent else { return }
        let migrator = PVAzaharDataMigrator(legacyRoot: PVAzaharDataMigrator.defaultLegacyRoot(),
                                            targetRoot: PVAzaharDataMigrator.defaultTargetRoot())
        guard !migrator.alreadyMigrated, migrator.plan().hasWork else { return }
        do {
            try migrator.apply()
            ILOG("[PVAzahar] auto-imported emuThreeDS data")
        } catch {
            ELOG("[PVAzahar] auto-import failed: \(error)")
        }
    }
}

extension PVAzaharCore: PV3DSSystemResponderClient {
    /// Controls live in the bridge's `+Controls.mm`; Swift cannot see that conformance statically.
    private var responder: PV3DSSystemResponderClient? {
        let responder = _bridge as? PV3DSSystemResponderClient
        assert(responder != nil, "PVAzaharCoreBridge must conform to PV3DSSystemResponderClient")
        return responder
    }

    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        responder?.didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PV3DSButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        responder?.didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PV3DSButton, forPlayer player: Int) {
        responder?.didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PV3DSButton, forPlayer player: Int) {
        responder?.didRelease(button, forPlayer: player)
    }
}

extension PVAzaharCore: GameWithCheat {
    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        do {
            try _bridge.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
            return true
        } catch {
            ELOG("setCheat failed: \(error)")
            return false
        }
    }
    public var supportsCheatCode: Bool { true }
    public var cheatCodeTypes: [String] { ["Gateway"] }
}

extension PVAzaharCore: CoreOptional {
    public static var options: [CoreOption] { PVAzaharCoreOptions.options }
}
