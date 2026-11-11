//
//  PVAlertModifier.swift
//  PVUI
//
//  SwiftUI entry points for `PVAlert`: `.pvAlert(isPresented:) { PVAlert(...) }`
//  and `.pvAlert(item:) { item in PVAlert(...) }`.
//

import SwiftUI

#if canImport(UIKit)
private struct PVAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    /// Returns nil when there is nothing to show any more.
    let makeAlert: () -> PVAlert?

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
        guard var alert = makeAlert() else {
            isPresented = false
            return
        }
        let binding = $isPresented
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

    /// Shows the alert built from `item` while it is non-nil, and sets it back to nil when
    /// the user answers. The binding is already nil when an action's handler runs, so
    /// handlers use the item `alert` was given, never the binding.
    func pvAlert<Item>(item: Binding<Item?>, _ alert: @escaping (Item) -> PVAlert) -> some View {
        let isPresented = Binding<Bool>(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )
        return modifier(PVAlertModifier(isPresented: isPresented) {
            item.wrappedValue.map(alert)
        })
    }
}
#endif
