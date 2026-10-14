//
//  PVPhysicalProfileController.swift
//  PVSupport
//
//  Wraps a GCController the system exposes without an extended gamepad (the
//  Nintendo Switch Online N64 controller on tvOS 17) and synthesizes one from
//  its physical input profile, so cores that only read `extendedGamepad` work.
//

#if canImport(UIKit) && canImport(GameController)
import GameController
import PVLogging

public final class PVPhysicalProfileController: GCController {
    /// The real controller. Its profile elements drive the synthesized synthesized.
    public let base: GCController
    private let synthesized = PVSynthesizedGamepad()
    /// Element name → synthesized input, as resolved for this pad.
    public private(set) var bindings: [String: PVSynthesizedInput] = [:]
    private var pausedHandler: ((GCController) -> Void)?
    private var cUp = false, cDown = false, cLeft = false, cRight = false
    private var _playerIndex: GCControllerPlayerIndex = .indexUnset

    /// True when `controller` has no extended or micro profile but its physical profile
    /// has a direction input and a face button to synthesize from.
    public static func isNeeded(for controller: GCController) -> Bool {
        guard controller.extendedGamepad == nil, controller.microGamepad == nil,
              !(controller is PVPhysicalProfileController) else { return false }
        let n64 = PVPhysicalProfileMapping.isN64Pad(vendorName: controller.vendorName, productCategory: controller.productCategory)
        let names = Array(controller.physicalInputProfile.elements.keys)
        return PVPhysicalProfileMapping.isUsable(bindings: PVPhysicalProfileMapping.bindings(forElementNames: names, isN64Pad: n64))
    }

    public init(wrapping controller: GCController) {
        base = controller
        super.init()
        synthesized.owner = self
        bind()
    }

    private func bind() {
        let profile = base.physicalInputProfile
        let n64 = PVPhysicalProfileMapping.isN64Pad(vendorName: base.vendorName, productCategory: base.productCategory)
        bindings = PVPhysicalProfileMapping.bindings(forElementNames: Array(profile.elements.keys), isN64Pad: n64)
        synthesized.hasOptions = bindings.values.contains(.options)
        synthesized.hasHome = bindings.values.contains(.home)
        ILOG("PVPhysicalProfileController[\(base.vendorName ?? "?")]: \(bindings.sorted { $0.key < $1.key }.map { "\($0.key)→\($0.value.rawValue)" }.joined(separator: ", "))")

        for (name, input) in bindings {
            guard let element = profile.elements[name] else { continue }
            switch input {
            case .dpad, .leftThumbstick, .rightThumbstick:
                guard let source = element as? GCControllerDirectionPad, let target = synthesized.pad(for: input) else { continue }
                source.valueChangedHandler = { [weak self, weak target] _, x, y in
                    guard let self, let target else { return }
                    target.update(x: x, y: y)
                    self.synthesized.notify(target)
                }
            case .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight:
                guard let source = element as? GCControllerButtonInput else { continue }
                source.valueChangedHandler = { [weak self] _, _, pressed in
                    self?.setCButton(input, pressed: pressed)
                }
            default:
                guard let source = element as? GCControllerButtonInput, let target = synthesized.button(for: input) else { continue }
                source.valueChangedHandler = { [weak self, weak target] _, value, pressed in
                    guard let self, let target else { return }
                    if target.isPressed != pressed { target.isPressed = pressed }
                    target.value = value
                    self.synthesized.notify(target)
                    if input == .home { self.pausedHandler?(self) }
                }
            }
        }
    }

    /// The N64 C cluster is four digital buttons; present them as the right stick.
    private func setCButton(_ input: PVSynthesizedInput, pressed: Bool) {
        switch input {
        case .rightStickUp: cUp = pressed
        case .rightStickDown: cDown = pressed
        case .rightStickLeft: cLeft = pressed
        case .rightStickRight: cRight = pressed
        default: return
        }
        let x: Float = (cRight ? 1 : 0) - (cLeft ? 1 : 0)
        let y: Float = (cUp ? 1 : 0) - (cDown ? 1 : 0)
        synthesized._rightThumbstick.update(x: x, y: y)
        synthesized.notify(synthesized._rightThumbstick)
    }

    // MARK: GCController

    public override var extendedGamepad: GCExtendedGamepad? { synthesized }
    public override var microGamepad: GCMicroGamepad? { nil }
    public override var physicalInputProfile: GCPhysicalInputProfile { base.physicalInputProfile }
    public override var vendorName: String? { base.vendorName }
    public override var productCategory: String { base.productCategory }
    public override var isAttachedToDevice: Bool { false }
    public override var haptics: GCDeviceHaptics? { base.haptics }
    public override var light: GCDeviceLight? { base.light }
    public override var battery: GCDeviceBattery? { base.battery }
    public override var motion: GCMotion? { base.motion }

    /// Cores poll a captured copy each frame; the synthesized elements are plain values,
    /// so the controller itself serves as its own snapshot.
    public override func capture() -> GCController { self }

    public override var playerIndex: GCControllerPlayerIndex {
        get { _playerIndex }
        set {
            _playerIndex = newValue
            base.playerIndex = newValue
        }
    }

    /// Fired by the pad's Home button, never by Start, so Start reaches the game.
    @available(iOS, deprecated: 13.0, message: "controllerPausedHandler has been deprecated. Use the Menu button found on the controller's profile, if it exists.")
    public override var controllerPausedHandler: ((GCController) -> Void)? {
        get { pausedHandler }
        set { pausedHandler = newValue }
    }
}

extension PVPhysicalProfileController: @unchecked Sendable {}
#endif
