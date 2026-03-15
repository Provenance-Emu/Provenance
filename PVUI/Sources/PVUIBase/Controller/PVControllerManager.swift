//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVControllerManager.swift
//  Provenance
//
//  Created by James Addyman on 19/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import Foundation
import GameController
import PVLibrary
import PVSupport
import PVSettings
import PVLogging
import PVEmulatorCore

#if !targetEnvironment(macCatalyst) && !os(macOS) && canImport(SteamController)
import SteamController
#endif

extension Notification.Name {
    static let PVControllerManagerControllerReassigned = Notification.Name("PVControllerManagerControllerReassignedNotification")
}

package
typealias iCadeListenCompletion = () -> Void

#if targetEnvironment(simulator)
    let isSimulator = true
#else
    let isSimulator = false
#endif

public final class PVControllerManager: NSObject, ObservableObject {

    // a filtered and augmented version of CGControllers.controllers()
//    public var allLiveControllers: [Int: GCController] {
//        return controllers.reduce(into: [:]) { (result, controller) in
//            result[controller.playerIndex.rawValue] = controller
//        }
//    }

    public var allLiveControllers: [Int: GCController] {
        var allLiveControllers = [Int: GCController]()
        if let player1 = player1 {
            allLiveControllers[1] = player1
        }
        if let player2 = player2 {
            allLiveControllers[2] = player2
        }
        if let player3 = player3 {
            allLiveControllers[3] = player3
        }
        if let player4 = player4 {
            allLiveControllers[4] = player4
        }
        if let player5 = player5 {
            allLiveControllers[5] = player5
        }
        if let player6 = player6 {
            allLiveControllers[6] = player6
        }
        if let player7 = player7 {
            allLiveControllers[7] = player7
        }
        if let player8 = player8 {
            allLiveControllers[8] = player8
        }

        return allLiveControllers
    }

    public private(set) var player1: GCController? {
        didSet {
            if player1 != oldValue {
                setController(player1, toPlayer: 1)
            }
        }
    }

    public private(set) var player2: GCController? {
        didSet {
            if player2 != oldValue {
                setController(player2, toPlayer: 2)
            }
        }
    }

    public private(set) var player3: GCController? {
        didSet {
            if player3 != oldValue {
                setController(player3, toPlayer: 3)
            }
        }
    }

    public private(set) var player4: GCController? {
        didSet {
            if player4 != oldValue {
                setController(player4, toPlayer: 4)
            }
        }
    }
    public private(set) var player5: GCController? {
        didSet {
            if player5 != oldValue {
                setController(player5, toPlayer: 5)
            }
        }
    }
    public private(set) var player6: GCController? {
        didSet {
            if player6 != oldValue {
                setController(player6, toPlayer: 6)
            }
        }
    }
    public private(set) var player7: GCController? {
        didSet {
            if player7 != oldValue {
                setController(player7, toPlayer: 7)
            }
        }
    }
    public private(set) var player8: GCController? {
        didSet {
            if player8 != oldValue {
                setController(player8, toPlayer: 8)
            }
        }
    }

#if canImport(UIKit) && canImport(GameController)
    public private(set) var iCadeController: PViCadeController?
#endif
    public private(set) var keyboardController: GCController?
    public var hasControllers: Bool {
        return player1 != nil || player2 != nil || player3 != nil || player4 != nil  || player5 != nil || player6 != nil || player7 != nil || player8 != nil
    }
    public var isKeyboardConnected: Bool {
        return keyboardController != nil
//        if #available(iOS 14.0, *) {
//            return GCKeyboard.coalesced != nil
//        } else {
//            return false
//        }
    }
    var skipKeyBinding:Bool = false
    var skipControllerBinding:Bool = false
    var hasLayout:Bool = false

    @MainActor
    public static let shared: PVControllerManager = PVControllerManager()

#if canImport(UIKit) && canImport(GameController)
    @MainActor
    package func listenForICadeControllers(window: UIWindow?, preferredPlayer: Int = -1, completion: iCadeListenCompletion? = nil) {
        iCadeController?.controllerPressedAnyKey = { [unowned self] (_) -> Void in
            var player = 0

            var controllerReplacing: GCController?
            if preferredPlayer == -1 {
                #if os(tvOS)
                    if self.player1 == nil || self.player1?.microGamepad != nil {
                        player = 1
                    } else if self.player2 == nil || self.player2?.microGamepad != nil {
                        player = 2
                    } else if self.player3 == nil || self.player3?.microGamepad != nil {
                        player = 3
                    } else if self.player4 == nil || self.player4?.microGamepad != nil {
                        player = 4
                    } else {
                        completion?()
                        return
                    }
                #else
                    if self.player1 == nil {
                        player = 1
                    } else if self.player2 == nil {
                        player = 2
                    } else if self.player3 == nil {
                        player = 3
                    } else if self.player4 == nil {
                        player = 4
                    } else {
                        completion?()
                        return
                    }
                #endif
            } else {
                player = preferredPlayer

                controllerReplacing = self.allLiveControllers[preferredPlayer]
            }

            self.setController(self.iCadeController, toPlayer: player)
            self.stopListeningForICadeControllers()
            NotificationCenter.default.post(name: .GCControllerDidConnect, object: PVControllerManager.shared.iCadeController)

            if let controllerReplacing = controllerReplacing {
                self.assign(controllerReplacing)
            }

            completion?()
        }
        iCadeController?.reader.shared.listen(to: window)
    }

    @MainActor
    package
    func stopListeningForICadeControllers() {
        iCadeController?.controllerPressedAnyKey = nil
        iCadeController?.reader.shared.listen(to: nil)
    }
#endif
    @MainActor
    override init() {
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleKeyboardConnect(_:)), name: .GCKeyboardDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleKeyboardDisconnect(_:)), name: .GCKeyboardDidDisconnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleControllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleControllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        UserDefaults.standard.addObserver(self as NSObject, forKeyPath: "kICadeControllerSettingKey", options: .new, context: nil)
        // automatically assign the first connected controller to player 1
        // prefer gamepad or extendedGamepad over a microGamepad
        assignControllers()
//        setupICade()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        UserDefaults.standard.removeObserver(self, forKeyPath: "kICadeControllerSettingKey")
    }

    func isAssigned(_ controller: GCController) -> Bool {
        return allLiveControllers.contains(where: { (_, existingController) -> Bool in
            controller == existingController
        })
    }

    func index(forController controller: GCController) -> Int? {
        if let (index, _) = allLiveControllers.first(where: { (_, existingController) -> Bool in
            controller == existingController
        }) {
            return index
        } else {
            return nil
        }
    }

#if canImport(UIKit) && canImport(GameController)
    @MainActor
    func setupICade() {
        if iCadeController == nil {
            let selectediCadeController = Defaults[.myiCadeControllerSetting]
            if selectediCadeController != .disabled {
                iCadeController = selectediCadeController.createController()
                if iCadeController != nil {
                    listenForICadeControllers()
                } else {
                    ELOG("Failed to create iCade controller")
                }
            }
        }
    }

    @MainActor
    public
    func resetICadeController() {
        if iCadeController != nil {
            stopListeningForICadeControllers()
            iCadeController = nil
        }

        setupICade()
    }
#endif

    @MainActor
    @objc func handleControllerDidConnect(_ note: Notification?) {
        guard !PVControllerManager.shared.skipControllerBinding else {
            return
        }
        guard let controller = note?.object as? GCController else {
            ELOG("Object wasn't a GCController")
            return
        }
        PVControllerManager.shared.connectController(controller);
    }

    @MainActor
    @objc func connectController(_ controller:GCController) {
        guard !PVControllerManager.shared.skipControllerBinding else {
            return
        }

        // ignore the bogus controller in the simulator
        if isSimulator && (controller.vendorName == nil || controller.vendorName == "Gamepad") {
            return
        }

        objectWillChange.send()
        let wrapper = getRemappableController(for: controller)
        /// Mappings are loaded in PVRemappableController.init(), no need to load again

#if !targetEnvironment(macCatalyst) && canImport(SteamController)  && !os(macOS)
        if let steamController = controller as? SteamController {
            #if os(tvOS)
            steamController.steamControllerMode = .keyboardAndMouse
            #endif
            steamController.steamButtonCombinationHandler = { (controller, button, down) in
                if down {
                    self.handleSteamControllerCombination(controller: controller, button: button)
                }
            }
        }
#endif

        ILOG("Controller connected: \(controller.vendorName ?? "No Vendor")")
        controller.setupPauseHandler(onPause: {
            NotificationCenter.default.post(name: NSNotification.Name("PauseGame"), object: nil)
        })
        assign(controller)
        #if os(iOS)
        if self.controllerUserInteractionEnabled {
            self.controllerUserInteractionEnabled = true
        }
        #endif
    }

    @MainActor
    @objc func handleControllerDidDisconnect(_ note: Notification?) {
        guard !PVControllerManager.shared.skipControllerBinding else {
            return
        }
        guard let controller = note?.object as? GCController else {
            ELOG("Object wasn't a GCController")
            return
        }
        PVControllerManager.shared.disconnectController(controller)
    }

    @MainActor
    @objc func disconnectController(_ controller: GCController) {
        ILOG("Controller disconnected: \(controller.vendorName ?? "No Vendor")")
        guard !PVControllerManager.shared.skipControllerBinding else {
            return
        }

        objectWillChange.send()
        removeRemappableController(for: controller)

        if controller == player1 {
            player1 = nil
        } else if controller == player2 {
            player2 = nil
        } else if controller == player3 {
            player3 = nil
        } else if controller == player4 {
            player4 = nil
        } else if controller == player5 {
            player5 = nil
        } else if controller == player6 {
            player6 = nil
        } else if controller == player7 {
            player7 = nil
        } else if controller == player8 {
            player8 = nil
        }

        var assigned = false
        if controller is PViCade8BitdoController || controller is PViCade8BitdoZeroController {
            if iCadeController != nil {
                Task.detached { @MainActor in
                    self.listenForICadeControllers()
                }
            }
        } else {
            assigned = assignControllers()
        }

        if !assigned {
            NotificationCenter.default.post(name: NSNotification.Name.PVControllerManagerControllerReassigned, object: self)
        }
    }

    @MainActor
    @objc func handleKeyboardConnect(_ note: Notification?) {
//        #if !targetEnvironment(simulator)
        ILOG("Keyboard Connected\n");
        if (PVControllerManager.shared.skipKeyBinding) {
            return
        }
        if let controller = GCKeyboard.coalesced?.createController() {

            keyboardController = controller
            PVControllerManager.shared.connectController(controller);
            NotificationCenter.default.post(name:Notification.Name("HideTouchControls"), object:nil)
        }
//        #endif
    }

    @MainActor
    @objc func handleKeyboardDisconnect(_ note: Notification?) {
        ILOG("Keyboard Disconnected\n");
        if let controller = keyboardController {
            keyboardController = nil
            PVControllerManager.shared.disconnectController(controller)
            NotificationCenter.default.post(name:Notification.Name("ShowTouchControls"), object:nil)
        }
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "kICadeControllerSettingKey" {
            Task.detached {
                await self.setupICade()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    @MainActor
    func listenForICadeControllers() {
        listenForICadeControllers(window: nil) { () -> Void in }
    }

#if !targetEnvironment(macCatalyst) && canImport(SteamController) && !os(macOS)
    func handleSteamControllerCombination(controller: SteamController, button: SteamControllerButton) {
        switch button {
        case .leftTrackpadClick:
            // toggle left trackpad click to input
            controller.steamLeftTrackpadRequiresClick = !controller.steamLeftTrackpadRequiresClick
        case .rightTrackpadClick:
            // toggle right trackpad click to input
            controller.steamRightTrackpadRequiresClick = !controller.steamRightTrackpadRequiresClick
        case .stick:
            // toggle stick mapping between d-pad and left stick
            if controller.steamThumbstickMapping == .leftThumbstick {
                controller.steamThumbstickMapping = .dPad
                controller.steamLeftTrackpadMapping = .leftThumbstick
            } else {
                controller.steamThumbstickMapping = .leftThumbstick
                controller.steamLeftTrackpadMapping = .dPad
            }
        default:
            return
        }
    }
#endif
    // MARK: - Controllers assignment
    public
    func setController(_ controller: GCController?, toPlayer player: Int) {
        if let controller = controller, let currentIndex = index(forController: controller), currentIndex != player {
            setController(nil, toPlayer: currentIndex)
        }

        #if TARGET_OS_TV
            // check if controller is iCade, otherwise crash
            if !((controller is PViCadeController) && controller?.microGamepad) {
                controller?.microGamepad?.allowsRotation = true
                controller?.microGamepad?.reportsAbsoluteDpadValues = true
            }
        #endif
        controller?.playerIndex = GCControllerPlayerIndex(rawValue: player - 1)!
        // TODO: keep an array of players/controllers we support more than 2 players
        if player == 1 {
            player1 = controller
        } else if player == 2 {
            player2 = controller
        } else if player == 3 {
            player3 = controller
        } else if player == 4 {
            player4 = controller
        } else if player == 5 {
            player5 = controller
        } else if player == 6 {
            player6 = controller
        } else if player == 7 {
            player7 = controller
        } else if player == 8 {
            player8 = controller
        }

        if let controller = controller {
            ILOG("Controller [\(controller.vendorName ?? "No Vendor")] assigned to player \(player)")
        }
    }

    public func controller(forPlayer player: Int) -> GCController? {
        return allLiveControllers[player]
    }

    public var controllers: [GCController] {
        var controllers = GCController.controllers()
        if let aController = iCadeController {
            controllers.append(aController)
        } else if let aController = keyboardController {
            controllers.append(aController)
        }
        // ignore the bogus controller in the simulator
        if isSimulator {
            controllers = controllers.filter({$0.vendorName != nil})
        }
        return controllers
    }

    @discardableResult
    func assignControllers() -> Bool {
        var assigned = false
        controllers.forEach { controller in
            if !allLiveControllers.contains(where: { (_, existingController) -> Bool in
                controller == existingController
            }) {
                assigned = assigned || assign(controller)
            }
        }

        return assigned
    }

    @discardableResult
    func assign(_ controller: GCController) -> Bool {
        if isAssigned(controller) {
            return false
        }

        ILOG("Assign controller \(controller.vendorName ?? "nil")")

        let id = controllerIdentifier(for: controller)
        var mode = slotMode(for: controller)

        // Guard against invalid persisted slot values. Treat out-of-range slots as `.auto`
        // to avoid crashing in `setController(_:toPlayer:)` when constructing GCControllerPlayerIndex.
        switch mode {
        case .preferred(let slot), .always(let slot):
            let validRange = 1...8
            if !validRange.contains(slot) {
                WLOG("Invalid controller slot \(slot) for controller [\(id)]; treating as .auto")
                mode = .auto
            }
        case .auto:
            break
        }

        switch mode {
        case .auto:
            break // fall through to auto-assign below

        case .preferred(let slot):
            // Claim the preferred slot only if it is currently free.
            if self.controller(forPlayer: slot) == nil {
                ILOG("Controller [\(id)] assigned to preferred slot \(slot)")
                setController(controller, toPlayer: slot)
                PVToastManager.post("\(id) assigned to Player \(slot)", type: .info, duration: 2.5, icon: "gamecontroller.fill")
                NotificationCenter.default.post(name: .PVControllerManagerControllerReassigned, object: self)
                return true
            } else {
                ILOG("Controller [\(id)] preferred slot \(slot) occupied; falling back to auto-assign")
            }

        case .always(let slot):
            // Always claim `slot`, bumping any current occupant to the next available slot.
            let occupant = self.controller(forPlayer: slot)
            if let occupant = occupant {
                let occupantID = controllerIdentifier(for: occupant)
                if case .always(let occupantSlot) = slotMode(for: occupant), occupantSlot == slot {
                    WLOG("Controller slot conflict: both \"\(id)\" and \"\(occupantID)\" have .always(\(slot)). Last-connected (\"\(id)\") wins.")
                    PVToastManager.post("Slot \(slot) conflict: \(id) displaced \(occupantID)", type: .warning, duration: 4.0, icon: "exclamationmark.triangle.fill")
                }
                // Evict occupant before claiming the slot.
                setController(nil, toPlayer: slot)
            }
            ILOG("Controller [\(id)] claimed slot \(slot) (always mode)")
            setController(controller, toPlayer: slot)
            PVToastManager.post("\(id) assigned to Player \(slot)", type: .info, duration: 2.5, icon: "gamecontroller.fill")
            if let occupant = occupant {
                let evictedName = controllerIdentifier(for: occupant)
                ILOG("Bumping evicted controller [\(evictedName)] from slot \(slot)")
                let newSlot = assignAuto(occupant)
                if newSlot {
                    if let newIndex = index(forController: occupant) {
                        PVToastManager.post("\(evictedName) moved to Player \(newIndex)", type: .info, duration: 3.0, icon: "arrow.right.circle.fill")
                    }
                } else {
                    PVToastManager.post("\(evictedName) was unassigned (no free slot)", type: .warning, duration: 3.5, icon: "xmark.circle.fill")
                }
            }
            NotificationCenter.default.post(name: .PVControllerManagerControllerReassigned, object: self)
            return true
        }

        return assignAuto(controller)
    }

    /// Auto-assign a controller to the first available slot, preferring to displace
    /// remote / keyboard controllers with physical gamepads (tvOS Siri Remote behaviour).
    @discardableResult
    private func assignAuto(_ controller: GCController) -> Bool {
        // Assign the controller to the first player without a controller assigned, or
        // if this is an extended controller, replace the first controller which is not extended (the Siri remote on tvOS).
        for i in 1 ... 8 {
            let previouslyAssignedController: GCController? = self.controller(forPlayer: i)
            let newGamepadNotRemote = !(controller.isRemote || controller.isKeyboard)
            let previousGamepadNotRemote = !((previouslyAssignedController?.isRemote == true) || (previouslyAssignedController?.isKeyboard == true))

            // Skip making duplicate
            if let previouslyAssignedController = previouslyAssignedController, previouslyAssignedController == controller {
                continue
            }

            if previouslyAssignedController == nil || (newGamepadNotRemote && !previousGamepadNotRemote) {
                let controllerName = controllerIdentifier(for: controller)
                setController(controller, toPlayer: i)
                PVToastManager.post("\(controllerName) assigned to Player \(i)", type: .info, duration: 2.5, icon: "gamecontroller.fill")
                // Move the previously assigned controller to another player
                if let previouslyAssignedController = previouslyAssignedController {
                    let displacedName = controllerIdentifier(for: previouslyAssignedController)
                    ILOG("Controller #\(i) \(displacedName) being reassigned")
                    PVToastManager.post("\(displacedName) displaced from Player \(i)", type: .info, duration: 3.0, icon: "arrow.right.circle.fill")
                    assign(previouslyAssignedController)
                }
                NotificationCenter.default.post(name: NSNotification.Name.PVControllerManagerControllerReassigned, object: self)
                return true
            }
        }
        return false
    }

#if !targetEnvironment(macCatalyst) && canImport(SteamController) && !os(macOS)
    func setSteamControllersMode(_ mode: SteamControllerMode) {
        for controller in SteamControllerManager.shared().controllers {
            controller.steamControllerMode = mode
        }
    }
#endif

    // MARK: - Controller User Interaction (ie use controller to drive UX)

    private static var savedValueChangedHandlers: [ObjectIdentifier: GCExtendedGamepadValueChangedHandler?] = [:]

    var controllerUserInteractionEnabled: Bool = false {
        didSet {
            /// Prevent redundant sets from corrupting savedValueChangedHandlers.
            /// Setting false→false would restore nil and destroy game input handlers.
            guard oldValue != controllerUserInteractionEnabled else { return }
            guard controllerUserInteractionEnabled else {
                controllers.forEach { controller in
                    if let gamepad = controller.extendedGamepad {
                        let id = ObjectIdentifier(controller)
                        gamepad.valueChangedHandler = Self.savedValueChangedHandlers[id] ?? nil
                        Self.savedValueChangedHandlers.removeValue(forKey: id)
                    } else {
                        controller.extendedGamepad?.valueChangedHandler = nil
                    }
                }
                return
            }
            controllers.forEach { controller in
                guard let gamepad = controller.extendedGamepad else { return }
                let id = ObjectIdentifier(controller)
                Self.savedValueChangedHandlers[id] = gamepad.valueChangedHandler
                var current_state = GCExtendedGamepad.ButtonState()
                let originalHandler = Self.savedValueChangedHandlers[id] ?? nil
                gamepad.valueChangedHandler = { gamepad, element in
                    let state = gamepad.readButtonState()
                    let changed_state = current_state.symmetricDifference(state)
                    let changed_state_pressed = changed_state.intersection(state)

                    let topVC = UIApplication.shared.windows.first { $0.isKeyWindow }?.topViewController
                    if let top = topVC as? ControllerButtonPress {
                        changed_state_pressed.forEach { top.controllerButtonPress($0) }
                    }
                    if let nav = topVC?.navigationController {
                        changed_state_pressed.forEach { nav.controllerButtonPress($0) }
                    }
                    current_state = state
                    originalHandler?(gamepad, element)
                }
            }
        }
    }
}

// MARK: - ControllerButtonPress protocol
public protocol ControllerButtonPress : UIViewController {
    typealias ButtonType = GCExtendedGamepad.ButtonType
    func controllerButtonPress(_ type:ButtonType)
}

//#if os(iOS)

// MARK: - UIWindow::topViewController

private extension UIWindow {
    var topViewController: UIViewController? {
        var top = self.rootViewController
        top = (top as? UINavigationController)?.topViewController ?? top
        while let presented = top?.presentedViewController {
            top = presented
        }
        top = (top as? UINavigationController)?.topViewController ?? top
        return top
    }
}

// MARK: - ControllerButtonPress - UINavigationController

extension UINavigationController : ControllerButtonPress {

    public func controllerButtonPress(_ type: ButtonType) {
        switch type {
        case .cancel:
             // if there is a BACK button, press it
            if self.navigationBar.backItem != nil {
                self.popViewController(animated: true)
            }
            // if there is a DONE button, press it (check both left and right bar items)
            else if let topItem = self.navigationBar.topItem {
                for bbi in [topItem.leftBarButtonItem, topItem.rightBarButtonItem].compactMap({ $0 }) {
                    if bbi.style == .done || bbi.action == NSSelectorFromString("done:") {
                        _ = bbi.target?.perform(bbi.action, with: bbi)
                        break
                    }
                }
            }
        default:
            break
        }
    }
}

// MARK: - ControllerButtonPress - UITableViewController

extension QuickTableViewController: ControllerButtonPressTableView {}
extension UITableViewController: ControllerButtonPressTableView {}
extension SortOptionsTableViewController: ControllerButtonPressTableView {}

public
protocol ControllerButtonPressTableView: ControllerButtonPress {
    var tableView: UITableView! { get }
    var clearsSelectionOnViewWillAppear: Bool { get set }
}

public
extension ControllerButtonPressTableView {

    func controllerButtonPress(_ type: ButtonType) {
        switch type {
        case .select:
            if let indexPath = tableView.indexPathForSelectedRow {
                clearsSelectionOnViewWillAppear = false
                tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)

                if let cell = tableView.cellForRow(at: indexPath) {
                    if cell.accessoryType != .none {
                        tableView.delegate?.tableView?(tableView, accessoryButtonTappedForRowWith: indexPath)
                    }
                    #if !os(tvOS)
                    if let sw = cell.accessoryView as? UISwitch {
                        sw.isOn = !sw.isOn
                        sw.sendActions(for: .valueChanged)
                    }
                    if let _ = cell.accessoryView as? UISlider {
                        // TODO: do we care?
                        WLOG("UISlider not implimented")
                    }
                    #endif
                }
            }
        case .up:
            moveSelection(-1)
        case .down:
            moveSelection(+1)
        default:
            break
        }
    }
    private func maxSection() -> Int {
        return tableView.numberOfSections-1
    }
    private func maxRow(_ indexPath:IndexPath) -> Int {
        return tableView.numberOfRows(inSection:indexPath.section)-1
    }
    private func select(_ indexPath:IndexPath) {
        // NOTE you might be tempted to use animated==true, but this causes massive redraw issues in scrolling table views, like Settings
        tableView.scrollToRow(at: indexPath, at: .none, animated: false)
        guard let cell = self.tableView.cellForRow(at: indexPath) else {
            ELOG("No cell for indexPath \(indexPath.debugDescription)")
            return
        }
        cell.selectedBackgroundView = cell.selectedBackgroundView ?? UIView()
        cell.selectedBackgroundView?.backgroundColor = navigationController?.view.tintColor ?? tableView.tintColor
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
    }
    private func moveSelection(_ dir:Int) {
        guard var indexPath = tableView.indexPathForSelectedRow else {
            return select(IndexPath(row:0, section:0))
        }
        // TODO: what about a (hidden) section with zero items
        if dir == -1 && indexPath.row == 0 && indexPath.section != 0 {
            indexPath.section -= 1
            indexPath.row = maxRow(indexPath)
        } else if dir == +1 && indexPath.row == maxRow(indexPath) && indexPath.section < maxSection() {
            indexPath.section += 1
            indexPath.row = 0
        } else {
            indexPath.row += dir
            indexPath.row = max(0, min(indexPath.row, maxRow(indexPath)))
        }
        select(indexPath)
    }
}

// MARK: - Read Controller UX buttons
//public
//extension GCExtendedGamepad {
//    public
//    enum ButtonType: String {
//        case a, b, x, y
//        case menu, options
//        case up, down, left, right
//        case l1, l2, r1, r2
//        static let select = a
//        static let back = b
//        static let cancel = b
//    }
//
//    public
//    typealias ButtonState = Set<ButtonType>
//
//    public
//    func readButtonState() -> ButtonState {
//        var state = ButtonState()
//
//        if buttonA.isPressed {state.formUnion([.a])}
//        if buttonB.isPressed {state.formUnion([.b])}
//        if buttonX.isPressed {state.formUnion([.x])}
//        if buttonY.isPressed {state.formUnion([.y])}
//        if buttonMenu.isPressed {state.formUnion([.menu])}
//        if buttonOptions?.isPressed == true {state.formUnion([.options])}
//
//        for pad in [dpad, leftThumbstick, rightThumbstick] {
//            if pad.up.isPressed {state.formUnion([.up])}
//            if pad.down.isPressed {state.formUnion([.down])}
//            if pad.left.isPressed {state.formUnion([.left])}
//            if pad.right.isPressed {state.formUnion([.right])}
//        }
//
//        if rightShoulder.isPressed {state.formUnion([.r1])}
//        if rightTrigger.isPressed {state.formUnion([.r2])}
//        if leftShoulder.isPressed {state.formUnion([.l1])}
//        if leftTrigger.isPressed {state.formUnion([.l2])}
//
//        return state
//    }
//}
//
// #endif  // os(iOS)

// MARK: - Controller type detection
//public
//extension GCController {
//    public
//    var isRemote: Bool {
//        return self.extendedGamepad == nil && self.microGamepad != nil
//    }
//    public
//    var isKeyboard: Bool {
//        if #available(iOS 14.0, tvOS 14.0, *) {
//            return isSnapshot && vendorName?.contains("Keyboard") == true
//        } else {
//            return false
//        }
//    }
//}

// MARK: - Keyboard Controller

//
// create a GCController that turns a keyboard into a controller
//
// [ESC:B]
// [TILDE:MENU] [1:OPTIONS]
//
// [TAB:L1]    [Q:X]     [W:UP]   [E:Y]     [R:R1]
//             [A:LEFT]  [S:DOWN] [D:RIGHT] [F:B]    [RETURN:A]
// [LSHIFT:L2]                              [V:R2]                     [UP]
//                       [SPACE:A]                             [LEFT] [DOWN] [RIGHT]
//
@available(iOS 14.0, tvOS 14.0, *)
public extension GCKeyboard {
    @MainActor
    func createController() -> GCController? {
        guard let keyboard = self.keyboardInput else {return nil}

        let controller = GCController.withExtendedGamepad()
        let gamepad = controller.extendedGamepad!

        let emulationUIState = AppState.shared.emulationUIState

        controller.setValue(self.vendorName ?? "Keyboard", forKey: "vendorName")

        keyboard.keyChangedHandler = {(keyboard, button, key, pressed) -> Void in
            //print("\(button) \(key) \(pressed)")

            func isPressed(_ code:GCKeyCode) -> Bool {
                return keyboard.button(forKeyCode:code)?.isPressed ?? false
            }

            // DPAD
            let dpad_x:Float = isPressed(.rightArrow) ? 1.0 : isPressed(.leftArrow) ? -1.0 : 0.0
            let dpad_y:Float = isPressed(.upArrow)    ? 1.0 : isPressed(.downArrow) ? -1.0 : 0.0
            gamepad.dpad.setValueForXAxis(dpad_x, yAxis:dpad_y)

            // WASD
            let left_x:Float = isPressed(.keyD) ? 1.0 : isPressed(.keyA) ? -1.0 : 0.0
            let left_y:Float = isPressed(.keyW) ? 1.0 : isPressed(.keyS) ? -1.0 : 0.0
            gamepad.leftThumbstick.setValueForXAxis(left_x, yAxis:left_y)

            // =[], || L;OK
            let right_x:Float = (isPressed(.closeBracket) || isPressed(.semicolon)) ? 1.0 : (isPressed(.openBracket) || isPressed(.keyK)) ? -1.0 : 0.0
            let right_y:Float = (isPressed(.equalSign) || isPressed(.keyO)) ? 1.0 : (isPressed(.hyphen) || isPressed(.keyL)) ? -1.0 : 0.0
            gamepad.rightThumbstick.setValueForXAxis(right_x, yAxis:right_y)

            // ABXY
            gamepad.buttonA.setValue(isPressed(.spacebar) || isPressed(.returnOrEnter) ? 1.0 : 0.0)
            gamepad.buttonB.setValue(isPressed(.keyF) || isPressed(.escape) ? 1.0 : 0.0)
            gamepad.buttonX.setValue(isPressed(.keyQ) ? 1.0 : 0.0)
            gamepad.buttonY.setValue(isPressed(.keyE) ? 1.0 : 0.0)

            // L1, L2
            gamepad.leftShoulder.setValue(isPressed(.tab) || isPressed(.capsLock) ? 1.0 : 0.0)
            gamepad.leftTrigger.setValue(isPressed(.leftShift) ? 1.0 : 0.0)

            // R1, R2
            gamepad.rightShoulder.setValue(isPressed(.keyR) ? 1.0 : 0.0)
            gamepad.rightTrigger.setValue(isPressed(.keyV) ? 1.0 : 0.0)

            // MENU, OPTIONS
            gamepad.buttonMenu.setValue(isPressed(.graveAccentAndTilde) ? 1.0 : 0.0)
            gamepad.buttonOptions?.setValue((isPressed(.one) || isPressed(.keyU)) ? 1.0 : 0.0)

            // L3, R3
            gamepad.leftThumbstickButton?.setValue(isPressed(.keyX) ? 1.0 : 0.0)
            gamepad.rightThumbstickButton?.setValue(isPressed(.keyC) ? 1.0 : 0.0)

            // the system does not call this handler in setValue, so call it with the dpad
            gamepad.valueChangedHandler?(gamepad, gamepad.dpad)

            // Bind / to select, rightShift to start
            if let emulator = emulationUIState.emulator, let core = emulationUIState.core, EmulationState.shared.stateSubject.value.isOn, core.isRunning {
                if (isPressed(.slash)) {
                    print("Select Pressed\n")
                    emulator.controllerViewController?.pressSelect(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        emulator.controllerViewController?.releaseSelect(forPlayer: 0)
                    })
                }
                if (isPressed(.rightShift)) {
                    print("Start Pressed\n")
                    emulator.controllerViewController?.pressStart(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        emulator.controllerViewController?.releaseStart(forPlayer: 0)
                    })
                }
            }
        }

        return controller
    }
}

public final class SortOptionsTableViewController: UIViewController {
    public var clearsSelectionOnViewWillAppear: Bool = true

    public private(set) var tableView: UITableView!

    public required init(withTableView tableView: UITableView) {
        super.init(nibName: nil, bundle: nil)

        self.tableView = tableView
    }

    public override func loadView() {
        self.view = tableView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Player-Slot Preferences

public extension PVControllerManager {

    /// A stable string identifier for a controller, used as a dictionary key for preferences.
    /// Uses ``GCController/vendorName`` when available, falling back to ``GCController/productCategory``.
    func controllerIdentifier(for controller: GCController) -> String {
        return controller.vendorName ?? controller.productCategory
    }

    // MARK: ControllerSlotMode API

    /// Returns the saved ``ControllerSlotMode`` for a controller, or `.auto` when none is stored.
    func slotMode(for controller: GCController) -> ControllerSlotMode {
        let id = controllerIdentifier(for: controller)
        return Defaults[.controllerSlotModes][id] ?? .auto
    }

    /// Persists the ``ControllerSlotMode`` for a controller.
    /// Setting `.auto` removes any stored preference (identical to calling ``clearSlotMode(for:)``).
    func setSlotMode(_ mode: ControllerSlotMode, for controller: GCController) {
        let id = controllerIdentifier(for: controller)
        var modes = Defaults[.controllerSlotModes]
        if case .auto = mode {
            modes.removeValue(forKey: id)
        } else {
            modes[id] = mode
        }
        objectWillChange.send()
        Defaults[.controllerSlotModes] = modes
        ILOG("Saved slot mode \(mode) for controller [\(id)]")
    }

    /// Removes any saved slot mode for a controller, reverting to `.auto`.
    func clearSlotMode(for controller: GCController) {
        setSlotMode(.auto, for: controller)
    }

    // MARK: ID-based slot mode API (for disconnected / previously-seen controllers)

    /// All controller identifiers that have a non-auto stored slot-mode preference.
    var storedControllerIds: [String] {
        Defaults[.controllerSlotModes]
            .compactMap { key, mode -> String? in
                if case .auto = mode { return nil }
                return key
            }
            .sorted()
    }

    /// Returns the saved ``ControllerSlotMode`` for a controller identified by its string ID, or `.auto` when none is stored.
    func slotMode(forId id: String) -> ControllerSlotMode {
        Defaults[.controllerSlotModes][id] ?? .auto
    }

    /// Persists the ``ControllerSlotMode`` for a controller identified by its string ID.
    /// Setting `.auto` removes any stored preference.
    func setSlotMode(_ mode: ControllerSlotMode, forId id: String) {
        var modes = Defaults[.controllerSlotModes]
        if case .auto = mode {
            modes.removeValue(forKey: id)
        } else {
            modes[id] = mode
        }
        objectWillChange.send()
        Defaults[.controllerSlotModes] = modes
        ILOG("Saved slot mode \(mode) for controller [\(id)]")
    }

    /// Removes any saved slot mode for the given controller ID, reverting to `.auto`.
    func clearSlotMode(forId id: String) {
        setSlotMode(.auto, forId: id)
    }

    /// Removes all saved controller slot preferences, reverting every controller to `.auto`.
    /// After clearing, re-assigns all connected controllers using auto-assignment.
    @MainActor
    func resetAllSlotPreferences() {
        Defaults[.controllerSlotModes] = [:]
        ILOG("All controller slot preferences have been reset")
        reapplyPreferences()
        PVToastManager.post("All controller preferences reset", type: .success, duration: 3.0, icon: "arrow.counterclockwise")
    }

    // MARK: Convenience Int-based API (kept for backward compatibility)

    /// Returns the stored preferred player slot (1–8) for a controller, or `nil` if none has been saved.
    ///
    /// This is a convenience wrapper over ``slotMode(for:)``.  It returns the slot number embedded in
    /// `.preferred(n)` or `.always(n)` modes, and `nil` for `.auto`.
    func preferredPlayer(for controller: GCController) -> Int? {
        return slotMode(for: controller).preferredSlot
    }

    /// Stores the preferred player slot for a controller so it is honoured on the next connect/reconnect.
    /// Pass `nil` (or a value outside 1–8) to clear the preference.
    ///
    /// This sets the slot mode to `.preferred(n)` (or `.auto` to clear), preserving any existing `.always(n)` override
    /// only when the requested slot number matches `n`.  Use ``setSlotMode(_:for:)`` to set `.always` mode explicitly.
    func setPreferredPlayer(_ player: Int?, for controller: GCController) {
        guard let player = player, player >= 1, player <= 8 else {
            clearSlotMode(for: controller)
            return
        }
        // Preserve .always if currently set to the same slot; otherwise write .preferred.
        if case .always(let current) = slotMode(for: controller), current == player {
            return // no change needed
        }
        setSlotMode(.preferred(player), for: controller)
    }

    /// Stores the preferred player slot using the controller's current player index.
    /// Call this after the user has manually re-ordered controllers so the preference is persisted.
    func saveCurrentPlayerSlotAsPreference(for controller: GCController) {
        if let currentSlot = index(forController: controller) {
            setPreferredPlayer(currentSlot, for: controller)
        }
    }

    // MARK: Re-apply on scene activation

    /// Re-applies saved slot preferences for all currently connected controllers.
    ///
    /// Call this when the emulator scene becomes active (e.g. after a tvOS focus/wake event) to
    /// restore preferred assignments that may have been reset by the system while the app was
    /// in the background.
    @MainActor
    func reapplyPreferences() {
        let liveControllers = Array(allLiveControllers.values)
        guard !liveControllers.isEmpty else { return }

        ILOG("Re-applying controller slot preferences for \(liveControllers.count) controller(s)")

        // Sort by priority so that .always controllers claim their slot first,
        // then .preferred, then .auto — avoiding unnecessary eviction cascades.
        let sorted = liveControllers.sorted { a, b in
            slotPriority(for: a) > slotPriority(for: b)
        }

        // Clear all player slots so we start from a clean state.
        for i in 1...8 { setController(nil, toPlayer: i) }

        // Re-assign each controller respecting its stored mode.
        for controller in sorted {
            assign(controller)
        }
    }
}

private extension PVControllerManager {
    /// Numeric sort priority used when ordering controllers in `reapplyPreferences()`.
    func slotPriority(for controller: GCController) -> Int {
        switch slotMode(for: controller) {
        case .always:    return 2
        case .preferred: return 1
        case .auto:      return 0
        }
    }
}

/// Dictionary to store remappable controller wrappers
private var remappableControllers: [GCController: PVRemappableController] = [:]

/// Get or create a remappable controller wrapper
private func getRemappableController(for controller: GCController) -> PVRemappableController {
    if let existing = remappableControllers[controller] {
        return existing
    }
    let wrapper = PVRemappableController(wrapping: controller)
    remappableControllers[controller] = wrapper
    return wrapper
}

/// Clear wrapper when controller disconnects
private func removeRemappableController(for controller: GCController) {
    remappableControllers.removeValue(forKey: controller)
}

// MARK: - Public remapping interface
public func remap(button source: ButtonIdentifier, to destination: ButtonIdentifier, forController controller: GCController) {
    let wrapper = getRemappableController(for: controller)
    wrapper.remap(button: source, to: destination)
    wrapper.saveMappings()
}

public func clearMappings(for controller: GCController) {
    let wrapper = getRemappableController(for: controller)
    wrapper.clearAllMappings()
    wrapper.saveMappings()
}

public func loadSavedMappings(for controller: GCController) {
    let wrapper = getRemappableController(for: controller)
    wrapper.loadMappings()
}

/// Get the remappable controller wrapper for a controller (for UI access)
public func getRemappableControllerWrapper(for controller: GCController) -> PVRemappableController {
    return getRemappableController(for: controller)
}
