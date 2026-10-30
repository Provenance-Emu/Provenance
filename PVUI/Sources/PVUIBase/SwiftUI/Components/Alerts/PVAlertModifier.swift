//
//  PVAlertModifier.swift
//  PVUI
//
//  SwiftUI entry point for `PVAlert`: `.pvAlert(isPresented:) { PVAlert(...) }`.
//

import SwiftUI

#if canImport(UIKit)
private struct PVAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let makeAlert: () -> PVAlert

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, presented in
                if presented { show() }
            }
            .onAppear {
                if isPresented { show() }
            }
    }

    private func show() {
        let binding = $isPresented
        var alert = makeAlert()
        let preferredIndex = alert.preferredActionID.flatMap { id in alert.actions.firstIndex { $0.id == id } }
        alert.actions = alert.actions.map { action in
            PVAlertAction(action.title, subtitle: action.subtitle, role: action.role) { response in
                binding.wrappedValue = false
                action.handler?(response)
            }
        }
        alert.preferredActionID = preferredIndex.map { alert.actions[$0].id }
        PVAlertCenter.shared.present(alert)
    }
}

public extension View {
    /// Shows the alert built by `alert` while `isPresented` is true, and sets it back to
    /// false when the user answers. Read text field values with
    /// `PVAlertAction(_:responseHandler:)`.
    func pvAlert(isPresented: Binding<Bool>, _ alert: @escaping () -> PVAlert) -> some View {
        modifier(PVAlertModifier(isPresented: isPresented, makeAlert: alert))
    }
}
#endif
