//
//  ButtonType.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import GameController

// #if os(iOS)

// MARK: - Read Controller UX buttons
public extension GCExtendedGamepad {
    enum ButtonType: String {
        case a, b, x, y
        case menu, options
        case up, down, left, right
        case l1, l2, r1, r2
        static let select = a
        static let back = b
        static let cancel = b
    }

    typealias ButtonState = Set<ButtonType>

    func readButtonState() -> ButtonState {
        var state = ButtonState()

        if buttonA.isPressed {state.formUnion([.a])}
        if buttonB.isPressed {state.formUnion([.b])}
        if buttonX.isPressed {state.formUnion([.x])}
        if buttonY.isPressed {state.formUnion([.y])}
        if buttonMenu.isPressed {state.formUnion([.menu])}
        if buttonOptions?.isPressed == true {state.formUnion([.options])}

        for pad in [dpad, leftThumbstick, rightThumbstick] {
            if pad.up.isPressed {state.formUnion([.up])}
            if pad.down.isPressed {state.formUnion([.down])}
            if pad.left.isPressed {state.formUnion([.left])}
            if pad.right.isPressed {state.formUnion([.right])}
        }

        if rightShoulder.isPressed {state.formUnion([.r1])}
        if rightTrigger.isPressed {state.formUnion([.r2])}
        if leftShoulder.isPressed {state.formUnion([.l1])}
        if leftTrigger.isPressed {state.formUnion([.l2])}

        return state
    }
}

//#endif // os(iOS)

// MARK: - Controller type detection
public extension GCController {
    var isRemote: Bool {
        return self.extendedGamepad == nil && self.microGamepad != nil
    }
    
    var isKeyboard: Bool {
        if #available(iOS 14.0, tvOS 14.0, *) {
            return isSnapshot && vendorName?.contains("Keyboard") == true
        } else {
            return false
        }
    }
}
