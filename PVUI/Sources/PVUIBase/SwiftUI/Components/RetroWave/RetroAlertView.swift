///
/// RetroAlertView.swift
/// Provenance
///
/// A native SwiftUI alert replacement with RetroWave styling
/// Created by Joseph Mattiello on 04/07/25.
///

import SwiftUI
import PVThemes

// MARK: - Alert Types

/// The type of alert to display
public enum RetroAlertType {
    case standard
    case loading
    case success
    case error
    case warning
}

/// Button style for RetroAlert buttons
public enum RetroAlertButtonStyle {
    case primary
    case secondary
    case destructive
    case cancel
}

// MARK: - RetroAlertView

/// A retrowave-themed alert view that replaces UIKit alerts with native SwiftUI
public struct RetroAlertView<Content: View>: View {
    // MARK: - Properties

    /// The title of the alert
    private let title: String

    /// The message of the alert
    private let message: String

    /// Binding to control presentation
    @Binding private var isPresented: Bool

    /// The type of alert
    private let alertType: RetroAlertType

    /// Optional text field binding
    private let textFieldBinding: Binding<String?>?

    /// Text field configuration
    private let textFieldConfiguration: ((UITextField) -> Void)?

    /// Content builder for buttons
    private let content: Content

    /// Animation state for glow effect
    @State private var glowOpacity: Double = 0.7

    /// Animation state for loading spinner
    @State private var spinnerRotation: Double = 0

    // MARK: - Initialization

    /// Creates a new RetroAlertView
    public init(
        title: String,
        message: String,
        isPresented: Binding<Bool>,
        alertType: RetroAlertType = .standard,
        textFieldBinding: Binding<String?>? = nil,
        textFieldConfiguration: ((UITextField) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.message = message
        self._isPresented = isPresented
        self.alertType = alertType
        self.textFieldBinding = textFieldBinding
        self.textFieldConfiguration = textFieldConfiguration
        self.content = content()
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Optional: Dismiss on background tap for non-loading alerts
                    if alertType != .loading {
                        // isPresented = false
                    }
                }

            // Alert container
            VStack(spacing: 20) {
                // Status icon for non-standard alerts
                if alertType != .standard {
                    statusIconView
                        .padding(.top, 8)
                }

                // Title
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, alertType == .standard ? 20 : 8)
                    .shadow(color: titleGlowColor.opacity(0.8), radius: 8, x: 0, y: 0)

                // Message
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .lineSpacing(4)

                // Text field if provided
                if let textBinding = textFieldBinding {
                    RetroTextField(text: textBinding, configuration: textFieldConfiguration)
                        .padding(.horizontal, 20)
                        .padding(.top, 5)
                }

                // Buttons
                content
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)
            }
            .frame(minWidth: 300, maxWidth: 400)
            .background(
                ZStack {
                    // Base background with gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.retroBlack,
                            Color.retroBlack.opacity(0.95)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Grid pattern
                    RetroAlertGridPattern()
                        .opacity(0.2)

                    // Scanline effect
                    RetroScanlineOverlay()
                        .opacity(0.05)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: borderColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: glowColor.opacity(glowOpacity), radius: 20, x: 0, y: 0)
            .onAppear {
                // Animate glow effect
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.3
                }

                // Animate spinner for loading type
                if alertType == .loading {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        spinnerRotation = 360
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Status Icon View

    @ViewBuilder
    private var statusIconView: some View {
        switch alertType {
        case .loading:
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(Color.retroBlue.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)

                // Spinning arc
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPink]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(spinnerRotation))
            }
            .shadow(color: Color.retroBlue.opacity(0.5), radius: 10)

        case .success:
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 70, height: 70)

                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 70, height: 70)

                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
            }
            .shadow(color: Color.green.opacity(0.6), radius: 10)

        case .error:
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 70, height: 70)

                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: 70, height: 70)

                Image(systemName: "xmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.red)
            }
            .shadow(color: Color.red.opacity(0.6), radius: 10)

        case .warning:
            ZStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.yellow, .orange]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: Color.orange.opacity(0.6), radius: 10)

        case .standard:
            EmptyView()
        }
    }

    // MARK: - Computed Properties

    private var borderColors: [Color] {
        switch alertType {
        case .standard, .loading:
            return [.retroPink, .retroBlue]
        case .success:
            return [.green, .retroBlue]
        case .error:
            return [.red, .retroPink]
        case .warning:
            return [.orange, .yellow]
        }
    }

    private var glowColor: Color {
        switch alertType {
        case .standard, .loading:
            return .retroPink
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        }
    }

    private var titleGlowColor: Color {
        switch alertType {
        case .standard, .loading:
            return .retroBlue
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        }
    }
}

// MARK: - Supporting Views

/// A retrowave-styled text field
public struct RetroTextField: View {
    @Binding var text: String?
    let configuration: ((UITextField) -> Void)?

    public var body: some View {
        ZStack {
            // Text field background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.retroBlack.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )

            // Use UITextField wrapper for advanced configuration
            UIKitTextField(text: $text, configuration: configuration)
                .padding(.horizontal, 10)
                .frame(height: 40)
        }
        .frame(height: 40)
    }
}

/// UITextField wrapper for SwiftUI
struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String?
    let configuration: ((UITextField) -> Void)?

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.textColor = .white
        textField.backgroundColor = .clear
        textField.tintColor = UIColor(Color.retroBlue)
        textField.returnKeyType = .done
        textField.autocorrectionType = .no

        // Apply custom configuration if provided
        configuration?(textField)

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UIKitTextField

        init(_ parent: UIKitTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

// MARK: - Button Styles

/// A retrowave-styled button with optional subtitle support
public struct RetroAlertButton: View {
    let title: String
    let subtitle: String?
    let style: RetroAlertButtonStyle
    let action: () -> Void
    /// Optional externally-controlled focus state for custom navigation.
    let isExternallyFocused: Bool?

    #if os(tvOS) || os(iOS)
    @FocusState private var isFocused: Bool
    #endif

    public init(
        title: String,
        subtitle: String? = nil,
        style: RetroAlertButtonStyle = .primary,
        isExternallyFocused: Bool? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.isExternallyFocused = isExternallyFocused
        self.action = action
    }

    public var body: some View {
        #if os(tvOS) || os(iOS)
        let isHighlighted = isExternallyFocused ?? isFocused
        #else
        let isHighlighted = false
        #endif
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textColor)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
            .padding(.vertical, subtitle != nil ? 10 : 12)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(backgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(focusedBorderGradient, lineWidth: focusedBorderWidth)
            )
            .scaleEffect(isHighlighted ? 1.08 : 1.0)
            .shadow(color: isHighlighted ? focusedGlowColor.opacity(0.9) : shadowColor.opacity(0.4), radius: isHighlighted ? 15 : 5)
        }
        #if os(tvOS) || os(iOS)
        .focused($isFocused)
        #endif
        #if os(tvOS)
//        .buttonStyle(PlainButtonStyle())
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #endif
    }

    #if os(tvOS) || os(iOS)
    private var focusedBorderGradient: LinearGradient {
        if isExternallyFocused ?? isFocused {
            return LinearGradient(
                gradient: Gradient(colors: [.retroPink, .retroBlue, .retroPink]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return borderGradient
        }
    }

    private var focusedBorderWidth: CGFloat {
        (isExternallyFocused ?? isFocused) ? 3 : 1
    }

    private var focusedGlowColor: Color {
        switch style {
        case .primary: return .retroPink
        case .secondary: return .retroBlue
        case .destructive: return .red
        case .cancel: return .retroBlue
        }
    }
    #else
    private var focusedBorderGradient: LinearGradient { borderGradient }
    private var focusedBorderWidth: CGFloat { 1 }
    #endif

    private var textColor: Color {
        .white
    }

    private var backgroundGradient: LinearGradient {
        switch style {
        case .primary:
            return LinearGradient(
                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .secondary:
            return LinearGradient(
                gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .destructive:
            return LinearGradient(
                gradient: Gradient(colors: [.red.opacity(0.8), .red.opacity(0.6)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .cancel:
            return LinearGradient(
                gradient: Gradient(colors: [Color.retroBlack.opacity(0.8), Color.retroBlack.opacity(0.6)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var borderGradient: LinearGradient {
        switch style {
        case .primary:
            return LinearGradient(
                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .secondary:
            return LinearGradient(
                gradient: Gradient(colors: [.gray, .gray.opacity(0.5)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .destructive:
            return LinearGradient(
                gradient: Gradient(colors: [.red, .orange]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .cancel:
            return LinearGradient(
                gradient: Gradient(colors: [.retroBlue.opacity(0.5), .retroPink.opacity(0.5)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary:
            return .retroPink
        case .secondary:
            return .gray
        case .destructive:
            return .red
        case .cancel:
            return .retroBlue
        }
    }
}

/// Legacy button for backwards compatibility
public struct RetroButton: View {
    let title: String
    let action: () -> Void
    let isPrimary: Bool

    public init(title: String, isPrimary: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isPrimary = isPrimary
        self.action = action
    }

    public var body: some View {
        RetroAlertButton(
            title: title,
            style: isPrimary ? .primary : .secondary,
            action: action
        )
    }
}

// MARK: - View Modifier

/// A view modifier to present a RetroAlertView
public struct RetroAlertModifier<AlertContent: View>: ViewModifier {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    let alertType: RetroAlertType
    let textFieldBinding: Binding<String?>?
    let textFieldConfiguration: ((UITextField) -> Void)?
    let alertContent: () -> AlertContent

    #if os(tvOS)
    @Namespace private var alertFocusNamespace
    #endif

    public init(
        title: String,
        message: String,
        isPresented: Binding<Bool>,
        alertType: RetroAlertType = .standard,
        textFieldBinding: Binding<String?>? = nil,
        textFieldConfiguration: ((UITextField) -> Void)? = nil,
        @ViewBuilder alertContent: @escaping () -> AlertContent
    ) {
        self.title = title
        self.message = message
        self._isPresented = isPresented
        self.alertType = alertType
        self.textFieldBinding = textFieldBinding
        self.textFieldConfiguration = textFieldConfiguration
        self.alertContent = alertContent
    }

    public func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isPresented)
                .allowsHitTesting(!isPresented)

            if isPresented {
                RetroAlertView(
                    title: title,
                    message: message,
                    isPresented: $isPresented,
                    alertType: alertType,
                    textFieldBinding: textFieldBinding,
                    textFieldConfiguration: textFieldConfiguration,
                    content: alertContent
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isPresented)
                .zIndex(1000)
            }
        }
        #if os(tvOS)
        .focusScope(alertFocusNamespace)
        #endif
    }
}

// MARK: - View Extension

public extension View {
    /// Presents a RetroAlertView when the binding is true
    func retroAlert<Content: View>(
        _ title: String,
        message: String,
        isPresented: Binding<Bool>,
        alertType: RetroAlertType = .standard,
        textFieldBinding: Binding<String?>? = nil,
        textFieldConfiguration: ((UITextField) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            RetroAlertModifier(
                title: title,
                message: message,
                isPresented: isPresented,
                alertType: alertType,
                textFieldBinding: textFieldBinding,
                textFieldConfiguration: textFieldConfiguration,
                alertContent: content
            )
        )
    }
}

// MARK: - Status Alert Convenience

/// A convenience view for showing status alerts (loading, success, error)
public struct RetroStatusAlert: View {
    let title: String
    let message: String
    let type: RetroAlertType
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    let onCancel: (() -> Void)?

    public init(
        title: String,
        message: String,
        type: RetroAlertType,
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.type = type
        self._isPresented = isPresented
        self.onDismiss = onDismiss
        self.onCancel = onCancel
    }

    public var body: some View {
        RetroAlertView(
            title: title,
            message: message,
            isPresented: $isPresented,
            alertType: type
        ) {
            if type == .loading {
                if let cancel = onCancel {
                    RetroAlertButton(title: "Cancel", style: .cancel) {
                        cancel()
                        isPresented = false
                    }
                }
            } else {
                RetroAlertButton(title: "OK", style: .primary) {
                    onDismiss?()
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Alert State Manager

/// Observable state for managing RetroWave alerts from anywhere in the app
@MainActor
public class RetroAlertState: ObservableObject {
    @Published public var isPresented: Bool = false
    @Published public var title: String = ""
    @Published public var message: String = ""
    @Published public var alertType: RetroAlertType = .standard
    @Published public var primaryButtonTitle: String = "OK"
    @Published public var secondaryButtonTitle: String? = nil
    @Published public var destructiveButtonTitle: String? = nil

    public var onPrimaryAction: (() -> Void)?
    public var onSecondaryAction: (() -> Void)?
    public var onDestructiveAction: (() -> Void)?
    public var onDismiss: (() -> Void)?

    public init() {}

    /// Show a simple alert with an OK button
    public func show(
        title: String,
        message: String,
        type: RetroAlertType = .standard,
        primaryButtonTitle: String = "OK",
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.alertType = type
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = nil
        self.destructiveButtonTitle = nil
        self.onPrimaryAction = nil
        self.onSecondaryAction = nil
        self.onDestructiveAction = nil
        self.onDismiss = onDismiss
        self.isPresented = true
    }

    /// Show an alert with multiple buttons
    public func show(
        title: String,
        message: String,
        type: RetroAlertType = .standard,
        primaryButtonTitle: String,
        primaryAction: (() -> Void)? = nil,
        secondaryButtonTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        destructiveButtonTitle: String? = nil,
        destructiveAction: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.alertType = type
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.destructiveButtonTitle = destructiveButtonTitle
        self.onPrimaryAction = primaryAction
        self.onSecondaryAction = secondaryAction
        self.onDestructiveAction = destructiveAction
        self.onDismiss = onDismiss
        self.isPresented = true
    }

    /// Hide the alert
    public func hide() {
        isPresented = false
        onDismiss?()
        // Reset state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.reset()
        }
    }

    private func reset() {
        title = ""
        message = ""
        alertType = .standard
        primaryButtonTitle = "OK"
        secondaryButtonTitle = nil
        destructiveButtonTitle = nil
        onPrimaryAction = nil
        onSecondaryAction = nil
        onDestructiveAction = nil
        onDismiss = nil
    }
}

// MARK: - Alert State View

/// A view that observes RetroAlertState and shows the appropriate alert
public struct RetroAlertStateView: View {
    @ObservedObject var alertState: RetroAlertState

    #if os(tvOS) || os(iOS)
    @FocusState private var focusedButton: AlertButton?

    private enum AlertButton: Hashable {
        case primary
        case secondary
        case destructive
    }
    #endif

    #if os(iOS)
    /// Gamepad input bridge for iOS controller navigation.
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif

    public init(alertState: RetroAlertState) {
        self.alertState = alertState
    }

    public var body: some View {
        if alertState.isPresented {
            // Full-screen overlay that blocks all interaction with content behind
            ZStack {
                // Invisible focusable blocker that prevents focus from escaping
                #if os(tvOS)
                Color.clear
                    .focusable(false)
                    .disabled(true)
                #endif

                RetroAlertView(
                    title: alertState.title,
                    message: alertState.message,
                    isPresented: $alertState.isPresented,
                    alertType: alertState.alertType
                ) {
                    VStack(spacing: 12) {
                        // Primary button
                        RetroAlertButton(
                            title: alertState.primaryButtonTitle,
                            style: .primary,
                            isExternallyFocused: isPrimaryFocused
                        ) {
                            alertState.onPrimaryAction?()
                            alertState.hide()
                        }
                        #if os(tvOS) || os(iOS)
                        .focused($focusedButton, equals: .primary)
                        #endif

                        // Secondary button if provided
                        if let secondaryTitle = alertState.secondaryButtonTitle {
                            RetroAlertButton(
                                title: secondaryTitle,
                                style: .secondary,
                                isExternallyFocused: isSecondaryFocused
                            ) {
                                alertState.onSecondaryAction?()
                                alertState.hide()
                            }
                            #if os(tvOS) || os(iOS)
                            .focused($focusedButton, equals: .secondary)
                            #endif
                        }

                        // Destructive button if provided
                        if let destructiveTitle = alertState.destructiveButtonTitle {
                            RetroAlertButton(
                                title: destructiveTitle,
                                style: .destructive,
                                isExternallyFocused: isDestructiveFocused
                            ) {
                                alertState.onDestructiveAction?()
                                alertState.hide()
                            }
                            #if os(tvOS) || os(iOS)
                            .focused($focusedButton, equals: .destructive)
                            #endif
                        }
                    }
                }
            }
            #if os(tvOS)
            .focusScope(alertFocusNamespace)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    focusedButton = .primary
                }
            }
            .onExitCommand {
                // Handle Menu/Back button press on tvOS - dismiss alert
                if let secondaryAction = alertState.onSecondaryAction {
                    secondaryAction()
                } else {
                    alertState.onDismiss?()
                }
                alertState.hide()
            }
            #endif
            #if os(iOS)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    focusedButton = .primary
                }
            }
            .onReceive(gamepadManager.eventPublisher) { event in
                guard alertState.isPresented, gamepadManager.isControllerConnected else { return }
                switch event {
                case .verticalNavigation(let value, let isPressed):
                    guard isPressed else { return }
                    moveFocus(isNext: value < 0)
                case .buttonPress(let isPressed):
                    guard isPressed else { return }
                    activateFocusedButton()
                case .buttonB(let isPressed):
                    guard isPressed else { return }
                    dismissFromCancel()
                default:
                    break
                }
            }
            #endif
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .animation(.easeInOut(duration: 0.2), value: alertState.isPresented)
            .zIndex(2000)
        }
    }

    #if os(tvOS)
    @Namespace private var alertFocusNamespace
    #endif

    #if os(tvOS) || os(iOS)
    private var isPrimaryFocused: Bool { focusedButton == .primary }
    private var isSecondaryFocused: Bool { focusedButton == .secondary }
    private var isDestructiveFocused: Bool { focusedButton == .destructive }
    #else
    private var isPrimaryFocused: Bool { false }
    private var isSecondaryFocused: Bool { false }
    private var isDestructiveFocused: Bool { false }
    #endif

    #if os(iOS)
    /// Ordered list of focusable alert buttons for controller navigation.
    private var availableButtons: [AlertButton] {
        var buttons: [AlertButton] = [.primary]
        if alertState.secondaryButtonTitle != nil {
            buttons.append(.secondary)
        }
        if alertState.destructiveButtonTitle != nil {
            buttons.append(.destructive)
        }
        return buttons
    }

    /// Moves focus up or down through the available buttons.
    private func moveFocus(isNext: Bool) {
        let buttons = availableButtons
        guard !buttons.isEmpty else { return }
        let current = focusedButton ?? .primary
        guard let index = buttons.firstIndex(of: current) else {
            focusedButton = buttons.first
            return
        }
        let nextIndex = isNext ? min(index + 1, buttons.count - 1) : max(index - 1, 0)
        focusedButton = buttons[nextIndex]
    }

    /// Triggers the action for the currently focused button.
    private func activateFocusedButton() {
        switch focusedButton ?? .primary {
        case .primary:
            alertState.onPrimaryAction?()
            alertState.hide()
        case .secondary:
            alertState.onSecondaryAction?()
            alertState.hide()
        case .destructive:
            alertState.onDestructiveAction?()
            alertState.hide()
        }
    }

    /// Dismisses the alert using the secondary action when available.
    private func dismissFromCancel() {
        if let secondaryAction = alertState.onSecondaryAction {
            secondaryAction()
        } else {
            alertState.onDismiss?()
        }
        alertState.hide()
    }
    #endif
}

// MARK: - View Modifier for Alert State

/// View modifier to attach a RetroAlertState to a view
public struct RetroAlertStateModifier: ViewModifier {
    @ObservedObject var alertState: RetroAlertState

    public init(alertState: RetroAlertState) {
        self.alertState = alertState
    }

    public func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(alertState.isPresented)
                .allowsHitTesting(!alertState.isPresented)
            RetroAlertStateView(alertState: alertState)
        }
    }
}

public extension View {
    /// Attaches a RetroAlertState to the view for showing alerts
    func retroAlertState(_ alertState: RetroAlertState) -> some View {
        modifier(RetroAlertStateModifier(alertState: alertState))
    }
}

// MARK: - Selection Alert

/// A generic data model for selection items with optional subtitle
public struct RetroSelectionItem: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?

    public init(id: String, title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

/// A retrowave-themed alert for selecting from a list of items
public struct RetroSelectionAlertView: View {
    private let title: String
    private let message: String
    private let items: [RetroSelectionItem]
    private let onSelect: (String) -> Void
    private let onCancel: () -> Void

    @Binding private var isPresented: Bool
    @State private var glowOpacity: Double = 0.7

    #if os(tvOS) || os(iOS)
    @FocusState private var focusedItemId: String?
    #endif

    #if os(tvOS)
    @Namespace private var selectionAlertFocusNamespace
    #endif

    #if os(iOS)
    /// Gamepad input bridge for iOS controller navigation.
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif

    public init(
        title: String,
        message: String,
        items: [RetroSelectionItem],
        isPresented: Binding<Bool>,
        onSelect: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.items = items
        self._isPresented = isPresented
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    private var useGridLayout: Bool {
        items.count > 4
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .shadow(color: Color.retroBlue.opacity(0.8), radius: 8, x: 0, y: 0)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .lineSpacing(4)

                ScrollView {
                    if useGridLayout {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(items) { item in
                                RetroAlertButton(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    style: .primary,
                                    isExternallyFocused: isItemFocused(item.id)
                                ) {
                                    isPresented = false
                                    onSelect(item.id)
                                }
                                #if os(tvOS) || os(iOS)
                                .focused($focusedItemId, equals: item.id)
                                #endif
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(items) { item in
                                RetroAlertButton(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    style: .primary,
                                    isExternallyFocused: isItemFocused(item.id)
                                ) {
                                    isPresented = false
                                    onSelect(item.id)
                                }
                                #if os(tvOS) || os(iOS)
                                .focused($focusedItemId, equals: item.id)
                                #endif
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .frame(maxHeight: useGridLayout ? 400 : 300)

                RetroAlertButton(
                    title: "Cancel",
                    style: .cancel,
                    isExternallyFocused: isCancelFocused
                ) {
                    isPresented = false
                    onCancel()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(minWidth: 300, maxWidth: useGridLayout ? 500 : 400)
            .background(
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.retroBlack,
                            Color.retroBlack.opacity(0.95)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    RetroAlertGridPattern()
                        .opacity(0.2)
                    RetroScanlineOverlay()
                        .opacity(0.05)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroBlue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: Color.retroPink.opacity(glowOpacity), radius: 20, x: 0, y: 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.3
                }
                #if os(tvOS) || os(iOS)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    focusedItemId = items.first?.id
                }
                #endif
            }
            #if os(tvOS)
            .onExitCommand {
                isPresented = false
                onCancel()
            }
            #endif
            #if os(iOS)
            .onReceive(gamepadManager.eventPublisher) { event in
                guard isPresented, gamepadManager.isControllerConnected else { return }
                switch event {
                case .verticalNavigation(let value, let isPressed):
                    guard isPressed else { return }
                    moveSelectionVertical(value: value)
                case .horizontalNavigation(let value, let isPressed):
                    guard isPressed else { return }
                    moveSelectionHorizontal(value: value)
                case .buttonPress(let isPressed):
                    guard isPressed else { return }
                    activateFocusedItem()
                case .buttonB(let isPressed):
                    guard isPressed else { return }
                    isPresented = false
                    onCancel()
                default:
                    break
                }
            }
            #endif
        }
        #if os(tvOS)
        .focusScope(selectionAlertFocusNamespace)
        #endif
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    /// Focus identifier used for the Cancel button in controller navigation.
    private let cancelFocusID = "__retro_alert_cancel__"

    #if os(tvOS) || os(iOS)
    private func isItemFocused(_ id: String) -> Bool {
        focusedItemId == id
    }

    private var isCancelFocused: Bool {
        focusedItemId == cancelFocusID
    }
    #else
    private func isItemFocused(_ id: String) -> Bool { false }
    private var isCancelFocused: Bool { false }
    #endif

    #if os(iOS)
    /// Moves focus vertically through the list/grid, falling back to Cancel when at the end.
    private func moveSelectionVertical(value: Float) {
        let isDown = value < 0
        if focusedItemId == cancelFocusID {
            if !isDown {
                focusedItemId = items.last?.id
            }
            return
        }
        guard let currentID = focusedItemId else {
            focusedItemId = items.first?.id
            return
        }
        guard let index = items.firstIndex(where: { $0.id == currentID }) else {
            focusedItemId = items.first?.id
            return
        }
        if useGridLayout {
            let stride = gridColumns.count
            if isDown {
                let nextIndex = index + stride
                if nextIndex < items.count {
                    focusedItemId = items[nextIndex].id
                } else {
                    focusedItemId = cancelFocusID
                }
            } else {
                let prevIndex = index - stride
                if prevIndex >= 0 {
                    focusedItemId = items[prevIndex].id
                }
            }
        } else {
            if isDown {
                if index + 1 < items.count {
                    focusedItemId = items[index + 1].id
                } else {
                    focusedItemId = cancelFocusID
                }
            } else if index > 0 {
                focusedItemId = items[index - 1].id
            }
        }
    }

    /// Moves focus horizontally within a grid row.
    private func moveSelectionHorizontal(value: Float) {
        guard useGridLayout else { return }
        guard focusedItemId != cancelFocusID else { return }
        let isRight = value > 0
        guard let currentID = focusedItemId else {
            focusedItemId = items.first?.id
            return
        }
        guard let index = items.firstIndex(where: { $0.id == currentID }) else {
            focusedItemId = items.first?.id
            return
        }
        let nextIndex = isRight ? index + 1 : index - 1
        guard nextIndex >= 0, nextIndex < items.count else { return }
        if (nextIndex / gridColumns.count) == (index / gridColumns.count) {
            focusedItemId = items[nextIndex].id
        }
    }

    /// Activates the focused item or cancel action.
    private func activateFocusedItem() {
        if focusedItemId == cancelFocusID {
            isPresented = false
            onCancel()
            return
        }
        let selectedID = focusedItemId ?? items.first?.id
        guard let selectedID else { return }
        isPresented = false
        onSelect(selectedID)
    }
    #endif
}

// MARK: - Selection Alert View Modifier

/// View modifier to present RetroSelectionAlertView
public struct RetroSelectionAlertModifier: ViewModifier {
    let title: String
    let message: String
    let items: [RetroSelectionItem]
    @Binding var isPresented: Bool
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    #if os(tvOS)
    @Namespace private var selectionFocusNamespace
    #endif

    public init(
        title: String,
        message: String,
        items: [RetroSelectionItem],
        isPresented: Binding<Bool>,
        onSelect: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.items = items
        self._isPresented = isPresented
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isPresented)
                .allowsHitTesting(!isPresented)

            if isPresented {
                RetroSelectionAlertView(
                    title: title,
                    message: message,
                    items: items,
                    isPresented: $isPresented,
                    onSelect: onSelect,
                    onCancel: onCancel
                )
                .animation(.easeInOut(duration: 0.2), value: isPresented)
                .zIndex(1000)
            }
        }
        #if os(tvOS)
        .focusScope(selectionFocusNamespace)
        #endif
    }
}

public extension View {
    /// Presents a selection alert with optional subtitles
    func retroSelectionAlert(
        title: String,
        message: String,
        items: [RetroSelectionItem],
        isPresented: Binding<Bool>,
        onSelect: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            RetroSelectionAlertModifier(
                title: title,
                message: message,
                items: items,
                isPresented: isPresented,
                onSelect: onSelect,
                onCancel: onCancel
            )
        )
    }
}

// MARK: - RetroSelectionAlertHostingView

/// Wraps ``RetroSelectionAlertView`` with its own `@State isPresented` so that
/// callers embedding the view in a `UIHostingController` or navigation stack do
/// not need to pass a writable binding.
public struct RetroSelectionAlertHostingView: View {
    let title: String
    let message: String
    let items: [RetroSelectionItem]
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @State private var isPresented = true

    public init(
        title: String,
        message: String,
        items: [RetroSelectionItem],
        onSelect: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.items = items
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public var body: some View {
        if isPresented {
            RetroSelectionAlertView(
                title: title,
                message: message,
                items: items,
                isPresented: $isPresented,
                onSelect: onSelect,
                onCancel: onCancel
            )
        }
    }
}
