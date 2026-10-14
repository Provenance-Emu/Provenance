//
//  PVSynthesizedGamepad.swift
//  PVSupport
//
//  An extended gamepad whose elements are set from code. Reuses the settable
//  element classes the iCade controller introduced.
//

#if canImport(UIKit) && canImport(GameController)
import GameController

/// Extended gamepad backed by settable elements; ``PVPhysicalProfileController`` drives it.
public final class PVSynthesizedGamepad: GCExtendedGamepad {
    let _dpad = PViCadeGamepadDirectionPad()
    let _leftThumbstick = PViCadeGamepadDirectionPad()
    let _rightThumbstick = PViCadeGamepadDirectionPad()
    let _buttonA = PViCadeGamepadButtonInput()
    let _buttonB = PViCadeGamepadButtonInput()
    let _buttonX = PViCadeGamepadButtonInput()
    let _buttonY = PViCadeGamepadButtonInput()
    let _leftShoulder = PViCadeGamepadButtonInput()
    let _rightShoulder = PViCadeGamepadButtonInput()
    let _leftTrigger = PViCadeGamepadButtonInput()
    let _rightTrigger = PViCadeGamepadButtonInput()
    let _menu = PViCadeGamepadButtonInput()
    let _options = PViCadeGamepadButtonInput()
    let _home = PViCadeGamepadButtonInput()

    /// Optional buttons are reported only when the physical pad has them, so the
    /// pause binding and the pause-menu "missing buttons" tiles see the truth.
    var hasOptions = false
    var hasHome = false

    weak var owner: GCController?
    private var _valueChangedHandler: GCExtendedGamepadValueChangedHandler?

    public override var controller: GCController? { owner }

    public override var dpad: GCControllerDirectionPad { _dpad }
    public override var leftThumbstick: GCControllerDirectionPad { _leftThumbstick }
    public override var rightThumbstick: GCControllerDirectionPad { _rightThumbstick }
    public override var buttonA: GCControllerButtonInput { _buttonA }
    public override var buttonB: GCControllerButtonInput { _buttonB }
    public override var buttonX: GCControllerButtonInput { _buttonX }
    public override var buttonY: GCControllerButtonInput { _buttonY }
    public override var leftShoulder: GCControllerButtonInput { _leftShoulder }
    public override var rightShoulder: GCControllerButtonInput { _rightShoulder }
    public override var leftTrigger: GCControllerButtonInput { _leftTrigger }
    public override var rightTrigger: GCControllerButtonInput { _rightTrigger }
    public override var buttonMenu: GCControllerButtonInput { _menu }
    public override var buttonOptions: GCControllerButtonInput? { hasOptions ? _options : nil }
    public override var buttonHome: GCControllerButtonInput? { hasHome ? _home : nil }
    public override var leftThumbstickButton: GCControllerButtonInput? { nil }
    public override var rightThumbstickButton: GCControllerButtonInput? { nil }

    public override var valueChangedHandler: GCExtendedGamepadValueChangedHandler? {
        get { _valueChangedHandler }
        set { _valueChangedHandler = newValue }
    }

    /// Element for a synthesized button input, or nil for pads and stick directions.
    func button(for input: PVSynthesizedInput) -> PViCadeGamepadButtonInput? {
        switch input {
        case .buttonA: return _buttonA
        case .buttonB: return _buttonB
        case .buttonX: return _buttonX
        case .buttonY: return _buttonY
        case .leftShoulder: return _leftShoulder
        case .rightShoulder: return _rightShoulder
        case .leftTrigger: return _leftTrigger
        case .rightTrigger: return _rightTrigger
        case .menu: return _menu
        case .options: return _options
        case .home: return _home
        default: return nil
        }
    }

    func pad(for input: PVSynthesizedInput) -> PViCadeGamepadDirectionPad? {
        switch input {
        case .dpad: return _dpad
        case .leftThumbstick: return _leftThumbstick
        case .rightThumbstick: return _rightThumbstick
        default: return nil
        }
    }

    /// Tells whole-gamepad observers (the menu navigation handler) that `element` changed.
    func notify(_ element: GCControllerElement) {
        _valueChangedHandler?(self, element)
    }
}

extension PVSynthesizedGamepad: @unchecked Sendable {}
#endif
