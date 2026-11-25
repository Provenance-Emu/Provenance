//
//  PVPhysicalProfileController.swift
//  PVSupport
//
//  Wraps a GCController the system exposes without an extended gamepad (the
//  Nintendo Switch Online N64/SNES/Mega Drive controllers, and plain USB/Bluetooth
//  HID pads) and synthesizes one from its physical input profile, so cores that
//  only read `extendedGamepad` work.
//

#if canImport(UIKit) && canImport(GameController)
import GameController
import PVLogging

/// Exported under a fixed Objective-C name so the native core bridges can recognize
/// it (`PVIsPhysicalProfileController` in PVCoreObjCBridge).
@objc(PVPhysicalProfileController)
public final class PVPhysicalProfileController: GCController {
    /// The real controller. Its profile elements drive the synthesized gamepad.
    public let base: GCController
    private let synthesized = PVSynthesizedGamepad()
    /// Element name → synthesized input, as resolved for this pad.
    public private(set) var bindings: [String: PVSynthesizedInput] = [:]
    /// Pad family the bindings were resolved for.
    public private(set) var pad: PVPhysicalProfilePad = .generic
    /// What opens the pause menu on this pad; nil when it has neither Home nor Select + Start.
    public private(set) var pauseTrigger: PVPauseTrigger?
    private var pausedHandler: ((GCController) -> Void)?
    private var cUp = false, cDown = false, cLeft = false, cRight = false
    private var _playerIndex: GCControllerPlayerIndex = .indexUnset
    /// Buttons the pad currently holds, before the pause trigger filters them.
    private var held: Set<PVSynthesizedInput> = []
    /// Set once the pause trigger fires; its inputs stay released to the game until all are let go.
    private var triggerLatched = false
    /// Trigger axes seen below zero, so known to rest at -1 rather than 0.
    private var bipolarAxes: Set<String> = []

    /// True when `controller` has no extended profile and its physical profile has a
    /// direction input and a face button to synthesize from: a Switch Online pad, or a
    /// generic HID pad (product category "HID", such as an 8BitDo pad over USB-C).
    ///
    /// Apple builds the Switch Online SNES pad from the same description class it uses
    /// for a basic (non-extended) MFi gamepad, so it reports a legacy `gamepad` and a
    /// `microGamepad` but no `extendedGamepad`. A generic pad may report a micro profile
    /// too, so that alone no longer rules a pad out; remotes are left alone
    /// (``PVPhysicalProfileMapping/shouldSynthesize(pad:productCategory:hasMicroGamepad:bindings:)``).
    public static func isNeeded(for controller: GCController) -> Bool {
        guard controller.extendedGamepad == nil, !(controller is PVPhysicalProfileController) else { return false }
        let pad = PVPhysicalProfilePad.detect(vendorName: controller.vendorName, productCategory: controller.productCategory)
        return PVPhysicalProfileMapping.shouldSynthesize(pad: pad,
                                                         productCategory: controller.productCategory,
                                                         hasMicroGamepad: controller.microGamepad != nil,
                                                         bindings: resolveBindings(for: controller, pad: pad))
    }

    /// Element name → input for `controller`. A Switch Online pad resolves by its
    /// family's names; any other pad also takes leftover elements by position.
    private static func resolveBindings(for controller: GCController, pad: PVPhysicalProfilePad) -> [String: PVSynthesizedInput] {
        let profile = controller.physicalInputProfile
        guard pad == .generic else {
            return PVPhysicalProfileMapping.bindings(forElementNames: Array(profile.elements.keys), pad: pad)
        }
        return PVPhysicalProfileMapping.genericBindings(buttonNames: Array(profile.buttons.keys),
                                                        directionNames: Array(profile.dpads.keys),
                                                        axisNames: Array(profile.axes.keys))
    }

    public init(wrapping controller: GCController) {
        base = controller
        super.init()
        synthesized.owner = self
        bind()
    }

    private func bind() {
        let profile = base.physicalInputProfile
        pad = PVPhysicalProfilePad.detect(vendorName: base.vendorName, productCategory: base.productCategory)
        bindings = Self.resolveBindings(for: base, pad: pad)
        pauseTrigger = PVPhysicalProfileMapping.pauseTrigger(forBindings: bindings)
        synthesized.hasOptions = bindings.values.contains(.options)
        synthesized.hasHome = bindings.values.contains(.home)
        synthesized.hasLeftThumbstickButton = bindings.values.contains(.leftThumbstickButton)
        synthesized.hasRightThumbstickButton = bindings.values.contains(.rightThumbstickButton)
        let described = bindings.sorted { $0.key < $1.key }.map { "\($0.key)→\($0.value.rawValue)" }.joined(separator: ", ")
        ILOG("PVPhysicalProfileController[\(base.vendorName ?? "?") \(pad.rawValue)] pause=\(String(describing: pauseTrigger)): \(described)")

        // `elements` can list one element under several names; each element drives exactly one input.
        var boundElements: Set<ObjectIdentifier> = []
        for (name, input) in bindings.sorted(by: { $0.key < $1.key }) {
            guard let element = profile.elements[name], boundElements.insert(ObjectIdentifier(element)).inserted else { continue }
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
                if let axis = element as? GCControllerAxisInput {
                    if PVPhysicalProfileMapping.triggerInputs.contains(input) { bindTriggerAxis(axis, to: input, named: name) }
                    continue
                }
                guard let source = element as? GCControllerButtonInput else { continue }
                if input == .menu || input == .options {
                    // Start and Select are game buttons; on tvOS the system would otherwise
                    // also treat them as a Menu press and open the pause menu.
                    source.preferredSystemGestureState = .disabled
                }
                source.valueChangedHandler = { [weak self] _, value, pressed in
                    self?.setButton(input, named: name, value: value, pressed: pressed)
                }
            }
        }
    }

    /// Drives a trigger from an axis. A trigger axis rests at 0 (range 0...1) on some
    /// pads and at -1 (range -1...1) on others; once it has reported a negative value
    /// it is treated as the second kind.
    private func bindTriggerAxis(_ axis: GCControllerAxisInput, to input: PVSynthesizedInput, named name: String) {
        if PVPhysicalProfileMapping.axisReadingIsBipolar(axis.value) { bipolarAxes.insert(name) }
        axis.valueChangedHandler = { [weak self] _, raw in
            guard let self else { return }
            if PVPhysicalProfileMapping.axisReadingIsBipolar(raw) { self.bipolarAxes.insert(name) }
            let state = PVPhysicalProfileMapping.triggerState(forAxisValue: raw, restsAtMinusOne: self.bipolarAxes.contains(name))
            self.setButton(input, named: name, value: state.value, pressed: state.pressed)
        }
    }

    /// Forwards a button to the synthesized gamepad unless it belongs to a pause trigger
    /// that has just fired, and fires the pause handler when the trigger completes.
    private func setButton(_ input: PVSynthesizedInput, named name: String, value: Float, pressed: Bool) {
        let wasHeld = held.contains(input)
        if pressed { held.insert(input) } else { held.remove(input) }
        if pressed && !wasHeld {
            ILOG("PVPhysicalProfileController[\(pad.rawValue)]: \(name) → \(input.rawValue)")
        }

        if let trigger = pauseTrigger {
            if triggerLatched {
                if held.isDisjoint(with: trigger.inputs) { triggerLatched = false }
                if trigger.inputs.contains(input) { return }
            } else if pressed, !wasHeld, trigger.isSatisfied(by: held) {
                triggerLatched = true
                for released in trigger.inputs { apply(released, value: 0, pressed: false) }
                pausedHandler?(self)
                return
            }
        }
        apply(input, value: value, pressed: pressed)
    }

    private func apply(_ input: PVSynthesizedInput, value: Float, pressed: Bool) {
        guard let target = synthesized.button(for: input) else { return }
        if target.isPressed != pressed { target.isPressed = pressed }
        target.value = value
        synthesized.notify(target)
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
    /// Never nil: remaps are stored per vendor name, and every unnamed pad would
    /// otherwise share the "unknown" entry.
    public override var vendorName: String? {
        base.vendorName ?? PVPhysicalProfileMapping.fallbackVendorName(productCategory: base.productCategory)
    }
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

    /// Fired by the pad's ``pauseTrigger`` (Home, or Select + Start), never by Start
    /// alone, so Start reaches the game.
    @available(iOS, deprecated: 13.0, message: "controllerPausedHandler has been deprecated. Use the Menu button found on the controller's profile, if it exists.")
    public override var controllerPausedHandler: ((GCController) -> Void)? {
        get { pausedHandler }
        set { pausedHandler = newValue }
    }
}

extension PVPhysicalProfileController: @unchecked Sendable {}
#endif
