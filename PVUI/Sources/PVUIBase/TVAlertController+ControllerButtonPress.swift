//
//  TVAlertController+ButtonPressed.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import PVUIBase

// MARK: - ControllerButtonPress - TVAlertController

extension ControllerButtonPress where Self: TVAlertController {
    public func controllerButtonPress(_ type: ButtonType) {
        VLOG("TVAlertController: \(type)")
        switch type {
        case .up:
            moveDefaultAction(-1)
            break;
        case .down:
            moveDefaultAction(+1)
            break;
        case .left:
            moveDefaultAction(-1000)
            break;
        case .right:
            moveDefaultAction(+1000)
            break;
        case .select:   // (aka A or ENTER)
            buttonPress(button(for: preferredAction))
            break;
#if os(iOS)
        case .back:     // (aka B or ESC)
            buttonPress(button(for: preferredAction))
            break;
#else
        case .back:     // (aka B or ESC)
            // only automaticly dismiss if there is a cancel button
            if cancelAction != nil {
                presentingViewController?.dismiss(animated:true, completion:nil)
            }
#endif
        default:
            break
        }
    }
    private func moveDefaultAction(_ dir:Int) {
        if let action = preferredAction, var idx = actions.firstIndex(of: action) {
            if doubleStackHeight != 0 {
                let n = self.doubleStackHeight
                if dir == +1 && idx == n-1 {idx = n*2-1}
                if dir == -1 && idx == n {idx = n+1}
                if dir == -1 && idx == n*2 {idx = n}
                if dir == +1000 && idx < n {idx = idx + n - 1000}
                if dir == -1000 && idx < n*2 {idx = idx - n + 1000}
            }
            idx = idx + dir
            if actions.indices.contains(idx) {
                preferredAction = actions[idx]
                button(for: action)?.isSelected = false
                button(for: preferredAction)?.isSelected = true
            }
        } else {
            preferredAction = actions.first(where: {$0.style == .default && $0.isEnabled})
            button(for: preferredAction)?.isSelected = true
        }
    }
}
