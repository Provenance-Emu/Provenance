//
//  PVAlertView.swift
//  PVUI
//
//  Renders a `PVAlert` in the RetroWave alert chrome. Hosted by
//  `PVAlertHostingController`; see `PVAlertCenter`.
//

import SwiftUI
import PVThemes

public struct PVAlertView: View {
    let alert: PVAlert
    let onAction: (PVAlertAction, PVAlertResponse) -> Void

    @State private var textValues: [String]
    @State private var toggleValue: Bool
    @State private var answered = false

    #if os(tvOS) || os(iOS)
    @FocusState private var focusedAction: PVAlertAction.ID?
    #endif
    #if os(tvOS)
    @Namespace private var focusNamespace
    #endif
    #if os(iOS)
    @ObservedObject private var gamepadManager = GamepadManager.shared
    #endif

    /// Lists longer than this scroll instead of growing past the screen.
    private static let maxButtonListHeight: CGFloat = 360
    /// Lets the focus engine settle on the alert before moving focus into it.
    private static let initialFocusDelay: TimeInterval = 0.15

    init(alert: PVAlert, onAction: @escaping (PVAlertAction, PVAlertResponse) -> Void) {
        self.alert = alert
        self.onAction = onAction
        _textValues = State(initialValue: alert.textFields.map(\.text))
        _toggleValue = State(initialValue: alert.toggle?.isOn ?? false)
    }

    public var body: some View {
        RetroAlertView(
            title: alert.title,
            message: alert.message ?? "",
            isPresented: .constant(true),
            alertType: alert.type
        ) {
            VStack(spacing: 16) {
                fieldsView
                buttonsView
            }
        }
        #if os(tvOS)
        .focusScope(focusNamespace)
        .onExitCommand {
            if let cancel = alert.cancelAction { choose(cancel) }
        }
        #endif
        #if os(iOS)
        .onReceive(gamepadManager.eventPublisher) { event in
            guard gamepadManager.isNavigationInputAvailable else { return }
            handleGamepad(event)
        }
        #endif
        #if os(tvOS) || os(iOS)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.initialFocusDelay) {
                focusedAction = alert.initialFocusID
            }
        }
        #endif
    }

    // MARK: Sections

    @ViewBuilder
    private var fieldsView: some View {
        ForEach(alert.textFields.indices, id: \.self) { index in
            let field = alert.textFields[index]
            Group {
                if field.isSecure {
                    SecureField(field.placeholder, text: $textValues[index])
                } else {
                    TextField(field.placeholder, text: $textValues[index])
                }
            }
            .textFieldStyle(.plain)
            .foregroundColor(.white)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.retroBlack.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.retroPink, .retroBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 20)
        }
        if let toggle = alert.toggle {
            Toggle(toggle.title, isOn: $toggleValue)
                .foregroundColor(.white)
                .tint(.retroPink)
                .padding(.horizontal, 20)
        }
    }

    private var buttonsView: some View {
        let actions = alert.orderedActions
        return ScrollView {
            VStack(spacing: 12) {
                ForEach(actions) { action in
                    RetroAlertButton(
                        title: action.title,
                        subtitle: action.subtitle,
                        style: buttonStyle(for: action),
                        isExternallyFocused: isFocused(action)
                    ) {
                        choose(action)
                    }
                    #if os(tvOS) || os(iOS)
                    .focused($focusedAction, equals: action.id)
                    #endif
                    #if os(tvOS)
                    .prefersDefaultFocus(action.id == alert.initialFocusID, in: focusNamespace)
                    #endif
                }
            }
            .padding(.vertical, 8)
            #if os(tvOS)
            .focusSection()
            #endif
        }
        .frame(maxHeight: Self.maxButtonListHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 4)
    }

    // MARK: Actions

    private func choose(_ action: PVAlertAction) {
        guard !answered else { return }
        answered = true
        onAction(action, PVAlertResponse(textValues: textValues, toggleValue: toggleValue))
    }

    private func buttonStyle(for action: PVAlertAction) -> RetroAlertButtonStyle {
        switch action.role {
        case .cancel: return .cancel
        case .destructive: return .destructive
        case .default: return action.id == alert.initialFocusID ? .primary : .secondary
        }
    }

    private func isFocused(_ action: PVAlertAction) -> Bool? {
        #if os(tvOS) || os(iOS)
        focusedAction == action.id
        #else
        nil
        #endif
    }

    #if os(iOS)
    /// Controllers on iOS don't drive the focus engine, so move focus by hand.
    private func handleGamepad(_ event: GamepadEvent) {
        let actions = alert.orderedActions
        switch event {
        case .verticalNavigation(let value, let isPressed):
            guard isPressed, !actions.isEmpty else { return }
            let current = actions.firstIndex { $0.id == focusedAction } ?? 0
            let next = value < 0 ? min(current + 1, actions.count - 1) : max(current - 1, 0)
            focusedAction = actions[next].id
        case .buttonPress(let isPressed):
            guard isPressed,
                  let action = actions.first(where: { $0.id == focusedAction }) ?? actions.first else { return }
            choose(action)
        case .buttonB(let isPressed):
            guard isPressed, let cancel = alert.cancelAction else { return }
            choose(cancel)
        default:
            break
        }
    }
    #endif
}

#if DEBUG
#Preview("PVAlert") {
    PVAlertView(
        alert: PVAlert(
            title: "Save State Detected",
            message: "Continue from where you left off?",
            actions: [
                PVAlertAction("Continue"),
                PVAlertAction("Restart"),
                PVAlertAction("Delete Save", role: .destructive),
                .cancel()
            ],
            toggle: PVAlertToggle("Auto Load Saves", isOn: false)
        ),
        onAction: { _, _ in }
    )
}
#endif
