//
//  PVRemappedController.swift
//  PVCoreBridge
//
//  Applies the user's per-controller button remaps (``ControllerMappingStore``)
//  for native cores. `PVEmulatorCore` hands a core this wrapper instead of the
//  real controller; its `extendedGamepad` returns the real elements, swapped, so
//  bridges that poll `isPressed`, set per-element handlers or `capture()` all see
//  the remap without per-core code.
//
//  Resolution matches the thin libretro wrapper's `remappedPressed`: reading
//  logical button X returns the physical button `destination(forSource: X)`.
//  The thin wrapper resolves through the store itself and opts out
//  (`PVEmulatorCore.appliesControllerRemapsItself`), so no remap applies twice.
//

#if canImport(GameController) && !os(watchOS)
import GameController

// MARK: - ButtonIdentifier → element

public extension GCExtendedGamepad {
    /// The element a ``ButtonIdentifier`` names on this gamepad, or nil when the
    /// pad has none. The platform Options/Share/Create buttons all surface as
    /// `buttonOptions`. Shared by ``PVRemappedController`` and the thin wrapper.
    func pvButton(for identifier: ButtonIdentifier) -> GCControllerButtonInput? {
        switch identifier {
        case .buttonA: return buttonA
        case .buttonB: return buttonB
        case .buttonX: return buttonX
        case .buttonY: return buttonY
        case .leftShoulder: return leftShoulder
        case .rightShoulder: return rightShoulder
        case .leftTrigger: return leftTrigger
        case .rightTrigger: return rightTrigger
        case .dpadUp: return dpad.up
        case .dpadDown: return dpad.down
        case .dpadLeft: return dpad.left
        case .dpadRight: return dpad.right
        case .menu: return buttonMenu
        case .options, .share, .createButton, .shareButton: return buttonOptions
        case .home: return buttonHome
        case .leftThumbstickButton: return leftThumbstickButton
        case .rightThumbstickButton: return rightThumbstickButton
        default: return nil
        }
    }
}

// MARK: - PVRemappedController

/// Exported under a fixed Objective-C name so `PVIsPhysicalProfileController`
/// (PVCoreObjCBridge) can look through it at ``base``.
@objc(PVRemappedController)
public final class PVRemappedController: GCController {
    /// Logical button → physical button it reads.
    public typealias Resolver = @Sendable (ButtonIdentifier) -> ButtonIdentifier

    /// The controller the user is holding. Pause binding, haptics and the menus keep using it.
    @objc public let base: GCController
    private let resolve: Resolver
    private let remappedGamepad: PVRemappedGamepad?

    /// The controller a core should be handed for `controller`.
    ///
    /// Returns `controller` itself when the core applies remaps on its own, when the
    /// pad has no extended profile, or when its vendor has no active remap, so
    /// players who never remap see the real controller. `PVEmulatorViewController`
    /// re-hands controllers on ``ControllerMappingStore/didChangeNotification``, which
    /// covers a remap added mid-session.
    public static func coreFacing(_ controller: GCController?,
                                  coreAppliesRemaps: Bool,
                                  store: ControllerMappingStore = .shared) -> GCController? {
        guard let controller, !coreAppliesRemaps, !(controller is PVRemappedController),
              controller.extendedGamepad != nil else { return controller }
        let vendor = mappingVendor(for: controller)
        guard store.hasActiveRemaps(forVendor: vendor) else { return controller }
        return PVRemappedController(wrapping: controller) { store.destination(forSource: $0, vendor: vendor) }
    }

    /// Store vendor key, as ``ControllerMappingStore`` and the thin wrapper use it.
    public static func mappingVendor(for controller: GCController) -> String {
        controller.vendorName ?? "unknown"
    }

    /// `resolve` is consulted on every read, so edits made while the wrapper is live apply at once.
    public init(wrapping controller: GCController, resolve: @escaping Resolver) {
        base = controller
        self.resolve = resolve
        remappedGamepad = controller.extendedGamepad.map { PVRemappedGamepad(base: $0, resolve: resolve) }
        super.init()
        remappedGamepad?.owner = self
    }

    // MARK: GCController

    public override var extendedGamepad: GCExtendedGamepad? { remappedGamepad }
    public override var microGamepad: GCMicroGamepad? { base.microGamepad }
    public override var physicalInputProfile: GCPhysicalInputProfile { base.physicalInputProfile }
    public override var vendorName: String? { base.vendorName }
    public override var productCategory: String { base.productCategory }
    public override var isAttachedToDevice: Bool { base.isAttachedToDevice }
    public override var isSnapshot: Bool { base.isSnapshot }
    public override var haptics: GCDeviceHaptics? { base.haptics }
    public override var light: GCDeviceLight? { base.light }
    public override var battery: GCDeviceBattery? { base.battery }
    public override var motion: GCMotion? { base.motion }

    public override var playerIndex: GCControllerPlayerIndex {
        get { base.playerIndex }
        set { base.playerIndex = newValue }
    }

    /// The real controller's snapshot with the remap written into it, so its class and
    /// family are the real pad's. Mupen captures every controller every frame, and a
    /// fresh wrapper costs a gamepad initialisation (~0.5 ms) where writing costs µs.
    /// A controller that is its own snapshot (`PVPhysicalProfileController`) can't be
    /// written to, so this wrapper is its snapshot too.
    public override func capture() -> GCController {
        let snapshot = base.capture()
        guard snapshot !== base, let gamepad = snapshot.extendedGamepad else { return self }
        PVRemap.write(resolve, into: gamepad)
        return snapshot
    }

    @available(iOS, deprecated: 13.0, message: "controllerPausedHandler has been deprecated. Use the Menu button found on the controller's profile, if it exists.")
    @available(tvOS, deprecated: 13.0, message: "controllerPausedHandler has been deprecated. Use the Menu button found on the controller's profile, if it exists.")
    public override var controllerPausedHandler: ((GCController) -> Void)? {
        get { base.controllerPausedHandler }
        set { base.controllerPausedHandler = newValue }
    }
}

extension PVRemappedController: @unchecked Sendable {}

// MARK: - Resolution

/// A real gamepad seen through a resolver. Every remapped element type holds one
/// (never a back-reference), so a captured element outlives the gamepad it came from.
struct PVRemap: @unchecked Sendable {
    let base: GCExtendedGamepad
    let resolve: PVRemappedController.Resolver

    /// The physical element logical button `id` reads, or nil when the pad lacks it.
    func element(_ id: ButtonIdentifier) -> GCControllerButtonInput? {
        base.pvButton(for: resolve(id))
    }

    /// For non-optional getters: a button mapped to an input this pad lacks is never pressed.
    func button(_ id: ButtonIdentifier) -> GCControllerButtonInput {
        element(id) ?? PVUnmappedButtonInput.shared
    }

    var isDpadRemapped: Bool {
        Self.dpadDirections.contains { resolve($0) != $0 }
    }

    private static let dpadDirections: [ButtonIdentifier] = [.dpadUp, .dpadDown, .dpadLeft, .dpadRight]

    /// The logical buttons `PVRemappedGamepad` remaps (Home and the sticks never move).
    private static let remappedButtons: [ButtonIdentifier] = [
        .buttonA, .buttonB, .buttonX, .buttonY, .leftShoulder, .rightShoulder,
        .leftTrigger, .rightTrigger, .menu, .options, .leftThumbstickButton, .rightThumbstickButton
    ]

    /// Rewrites a snapshot so each logical button holds the value of the physical button
    /// it reads. Every value is read before any is written, so swaps stay swaps.
    static func write(_ resolve: PVRemappedController.Resolver, into snapshot: GCExtendedGamepad) {
        func value(_ id: ButtonIdentifier) -> Float { snapshot.pvButton(for: resolve(id))?.value ?? 0 }

        let moved = remappedButtons.filter { resolve($0) != $0 }
        let values = moved.map(value)
        let dpadRemapped = dpadDirections.contains { resolve($0) != $0 }
        let x = dpadRemapped ? value(.dpadRight) - value(.dpadLeft) : 0
        let y = dpadRemapped ? value(.dpadUp) - value(.dpadDown) : 0

        for (id, newValue) in zip(moved, values) {
            snapshot.pvButton(for: id)?.setValue(newValue)
        }
        if dpadRemapped {
            snapshot.dpad.setValueForXAxis(x, yAxis: y)
        }
    }
}

// MARK: - PVRemappedGamepad

/// The remapped view of a real extended gamepad. Its elements are the real
/// elements, so their state and handlers belong to the real pad; `capture()`
/// returns the real snapshot with the remap written in.
///
/// It reports itself as the real pad's family (DualSense, DualShock, Xbox) and
/// forwards that family's extra selectors (`touchpadButton`, `buttonShare`, …) to
/// the real pad, because native bridges pick Start/Select per family.
final class PVRemappedGamepad: GCExtendedGamepad {
    let remap: PVRemap
    weak var owner: GCController?
    private let remappedDpad: PVRemappedDirectionPad
    private var _valueChangedHandler: GCExtendedGamepadValueChangedHandler?

    var base: GCExtendedGamepad { remap.base }

    init(base: GCExtendedGamepad, resolve: @escaping PVRemappedController.Resolver) {
        remap = PVRemap(base: base, resolve: resolve)
        remappedDpad = PVRemappedDirectionPad(remap: remap)
        super.init()
    }

    override var controller: GCController? { owner }

    override var dpad: GCControllerDirectionPad { remap.isDpadRemapped ? remappedDpad : base.dpad }
    override var leftThumbstick: GCControllerDirectionPad { base.leftThumbstick }
    override var rightThumbstick: GCControllerDirectionPad { base.rightThumbstick }
    override var buttonA: GCControllerButtonInput { remap.button(.buttonA) }
    override var buttonB: GCControllerButtonInput { remap.button(.buttonB) }
    override var buttonX: GCControllerButtonInput { remap.button(.buttonX) }
    override var buttonY: GCControllerButtonInput { remap.button(.buttonY) }
    override var leftShoulder: GCControllerButtonInput { remap.button(.leftShoulder) }
    override var rightShoulder: GCControllerButtonInput { remap.button(.rightShoulder) }
    override var leftTrigger: GCControllerButtonInput { remap.button(.leftTrigger) }
    override var rightTrigger: GCControllerButtonInput { remap.button(.rightTrigger) }
    override var buttonMenu: GCControllerButtonInput { remap.button(.menu) }
    override var buttonOptions: GCControllerButtonInput? { remap.element(.options) }
    /// Home opens the pause menu, so a remap never moves it (the thin wrapper doesn't either).
    override var buttonHome: GCControllerButtonInput? { base.buttonHome }
    override var leftThumbstickButton: GCControllerButtonInput? { remap.element(.leftThumbstickButton) }
    override var rightThumbstickButton: GCControllerButtonInput? { remap.element(.rightThumbstickButton) }

    // The profile dictionaries are the real pad's, unremapped (a fresh gamepad has its own set).
    override var elements: [String: GCControllerElement] { base.elements }
    override var buttons: [String: GCControllerButtonInput] { base.buttons }
    override var axes: [String: GCControllerAxisInput] { base.axes }
    override var dpads: [String: GCControllerDirectionPad] { base.dpads }
    override var allElements: Set<GCControllerElement> { base.allElements }
    override var allButtons: Set<GCControllerButtonInput> { base.allButtons }
    override var allAxes: Set<GCControllerAxisInput> { base.allAxes }
    override var allDpads: Set<GCControllerDirectionPad> { base.allDpads }

    /// Installed on the real pad; the handler receives this gamepad, so comparing the
    /// element against `gamepad.buttonA` matches the remapped button.
    override var valueChangedHandler: GCExtendedGamepadValueChangedHandler? {
        get { _valueChangedHandler }
        set {
            _valueChangedHandler = newValue
            base.valueChangedHandler = newValue.map { handler in
                { [weak self] _, element in
                    guard let self else { return }
                    handler(self, element)
                }
            }
        }
    }

    /// The real pad's snapshot with the remap written into it (see
    /// `PVRemappedController.capture()`): Mednafen captures once per button it reads.
    ///
    /// `capture` is `instancetype`, imported as `-> Self`, but the snapshot is the real
    /// pad's class (GCDualSenseGamepad and so on), not this one. Callers only ever see
    /// it as a `GCExtendedGamepad` (this class is internal), so reinterpreting the
    /// reference is safe; `unsafeDowncast` would trap in Debug, because it checks.
    override func capture() -> Self {
        let snapshot = base.capture()
        guard snapshot !== base else { return self }
        PVRemap.write(remap.resolve, into: snapshot)
        return Unmanaged<Self>.fromOpaque(Unmanaged.passUnretained(snapshot).toOpaque()).takeUnretainedValue()
    }

    // MARK: Family identity

    private static let forwardedFamilies: [AnyClass] = [
        GCDualSenseGamepad.self, GCDualShockGamepad.self, GCXboxGamepad.self
    ]

    override func isKind(of aClass: AnyClass) -> Bool {
        if super.isKind(of: aClass) { return true }
        return Self.forwardedFamilies.contains { $0 == aClass } && base.isKind(of: aClass)
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || base.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? { base }
}

extension PVRemappedGamepad: @unchecked Sendable {}

// MARK: - PVRemappedDirectionPad

/// The d-pad when one of its directions is remapped: each direction reads its
/// remapped element and the axes follow those directions.
final class PVRemappedDirectionPad: GCControllerDirectionPad {
    private let remap: PVRemap
    private let _xAxis: PVRemappedAxis
    private let _yAxis: PVRemappedAxis

    init(remap: PVRemap) {
        self.remap = remap
        _xAxis = PVRemappedAxis { remap.button(.dpadRight).value - remap.button(.dpadLeft).value }
        _yAxis = PVRemappedAxis { remap.button(.dpadUp).value - remap.button(.dpadDown).value }
        super.init()
    }

    override var up: GCControllerButtonInput { remap.button(.dpadUp) }
    override var down: GCControllerButtonInput { remap.button(.dpadDown) }
    override var left: GCControllerButtonInput { remap.button(.dpadLeft) }
    override var right: GCControllerButtonInput { remap.button(.dpadRight) }
    override var xAxis: GCControllerAxisInput { _xAxis }
    override var yAxis: GCControllerAxisInput { _yAxis }

    /// Fires on the real d-pad's changes with the remapped axes. Presses of a face
    /// button mapped onto a direction don't fire it; polling cores see them.
    override var valueChangedHandler: GCControllerDirectionPadValueChangedHandler? {
        get { remap.base.dpad.valueChangedHandler }
        set {
            remap.base.dpad.valueChangedHandler = newValue.map { handler in
                { [weak self] _, _, _ in
                    guard let self else { return }
                    handler(self, self._xAxis.value, self._yAxis.value)
                }
            }
        }
    }
}

extension PVRemappedDirectionPad: @unchecked Sendable {}

/// A d-pad axis computed from its two remapped directions.
final class PVRemappedAxis: GCControllerAxisInput {
    private let compute: @Sendable () -> Float

    init(_ compute: @escaping @Sendable () -> Float) {
        self.compute = compute
        super.init()
    }

    override var value: Float { compute() }
}

extension PVRemappedAxis: @unchecked Sendable {}

/// Stands in for a remap destination the pad doesn't have (a paddle, SL/SR): never pressed.
final class PVUnmappedButtonInput: GCControllerButtonInput {
    static let shared = PVUnmappedButtonInput()

    override var value: Float { 0 }
    override var isPressed: Bool { false }
}

extension PVUnmappedButtonInput: @unchecked Sendable {}
#endif
