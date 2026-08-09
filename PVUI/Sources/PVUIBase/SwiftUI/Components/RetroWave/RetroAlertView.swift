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

    /// Animation state for glow effect (subtle pulse; aligned with `RetroPauseChrome` panel family).
    @State private var glowOpacity: Double = 0.5

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
            .clipShape(RoundedRectangle(cornerRadius: RetroPauseChrome.panelCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: RetroPauseChrome.panelCornerRadius)
                    .strokeBorder(alertBorderGradient, lineWidth: RetroPauseChrome.panelStrokeLineWidth)
            )
            .shadow(color: glowColor.opacity(glowOpacity), radius: 12, x: 0, y: 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.28
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

    /// Standard/loading alerts use the same purple→pink frame as `PauseTileMenuView`; semantic types keep tinted borders.
    private var alertBorderGradient: LinearGradient {
        switch alertType {
        case .standard, .loading:
            return RetroPauseChrome.panelBorderGradient
        case .success, .error, .warning:
            return LinearGradient(
                gradient: Gradient(colors: borderColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                        #if os(tvOS)
                        /// Forces tvOS's focus engine to pick this button as the default
                        /// focus target within the alert's focus scope on appear. Without
                        /// this hint, focus can remain on whatever view was focused
                        /// behind the alert (e.g. a TVMediaMainView tile), leaving the
                        /// alert un-navigable by an MFi controller even though the
                        /// buttons are visible.
                        .prefersDefaultFocus(true, in: alertFocusNamespace)
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
                    #if os(tvOS)
                    /// Group the buttons as a single focus section so tvOS's focus
                    /// engine treats up/down navigation between them as in-scope,
                    /// and so the whole group is picked up as the default focus
                    /// region when the alert appears over existing content.
                    .focusSection()
                    #endif
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
                guard alertState.isPresented, gamepadManager.isNavigationInputAvailable else { return }
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
