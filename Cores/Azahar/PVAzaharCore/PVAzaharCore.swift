import Foundation
import PVCoreBridge
import PVEmulatorCore
import PVLogging
import PVSupport

@objc @objcMembers
public final class PVAzaharCore: PVEmulatorCore, @unchecked Sendable {
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
                name: Notification.Name("PVEmulatorCoreDidFailToStart"),
                object: nil,
                userInfo: [
                    "error": NSError(domain: "PVAzaharCore", code: 1, userInfo: [NSLocalizedDescriptionKey: message]),
                    "coreIdentifier": self.coreIdentifier ?? ""
                ]
            )
            MainActor.assumeIsolated { self.emulationDidFailToStart() }
        }
    }

    public override func loadFile(atPath path: String) throws {
        PVAzaharCoreOptions.apply(to: _bridge)
        try super.loadFile(atPath: path)
    }
}

extension PVAzaharCore: PV3DSSystemResponderClient {
    /// Controls live in the bridge's `+Controls.mm`; Swift cannot see that conformance statically.
    private var responder: PV3DSSystemResponderClient? { _bridge as? PV3DSSystemResponderClient }

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
