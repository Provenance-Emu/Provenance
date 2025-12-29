///
/// RetroAlertNavigationStack.swift
/// Provenance
///
/// A navigation stack for RetroWave-themed alerts with push/pop transitions
/// Created by Joseph Mattiello on 12/29/25.
///

import SwiftUI
import PVThemes

// MARK: - Navigation Stack Item

/// Wrapper for views in the navigation stack with unique identifier
public struct RetroAlertStackItem: Identifiable {
    public let id: String
    public let view: AnyView

    public init<V: View>(id: String = UUID().uuidString, view: V) {
        self.id = id
        self.view = AnyView(view)
    }
}

// MARK: - Navigation Direction

/// Direction of navigation transition
public enum RetroAlertNavigationDirection {
    case forward
    case backward
}

// MARK: - RetroAlertNavigationStack

/// Observable class managing a stack of alert views with animated transitions
@MainActor
public class RetroAlertNavigationStack: ObservableObject {

    /// The stack of alert views
    @Published public private(set) var alertStack: [RetroAlertStackItem] = []

    /// Whether the navigation stack is being presented
    @Published public var isPresented: Bool = false

    /// Current navigation direction for animation
    @Published public private(set) var navigationDirection: RetroAlertNavigationDirection = .forward

    /// Callback when stack is fully dismissed
    public var onDismiss: (() -> Void)?

    public init() {}

    /// Pushes a new view onto the stack with forward animation
    public func push<V: View>(_ view: V, id: String = UUID().uuidString) {
        navigationDirection = .forward
        let item = RetroAlertStackItem(id: id, view: view)
        withAnimation(.easeInOut(duration: 0.25)) {
            alertStack.append(item)
            if !isPresented {
                isPresented = true
            }
        }
    }

    /// Pops the top view from the stack with backward animation
    public func pop() {
        guard alertStack.count > 1 else {
            dismiss()
            return
        }
        navigationDirection = .backward
        withAnimation(.easeInOut(duration: 0.25)) {
            _ = alertStack.popLast()
        }
    }

    /// Pops all views except the root
    public func popToRoot() {
        guard alertStack.count > 1 else { return }
        navigationDirection = .backward
        withAnimation(.easeInOut(duration: 0.25)) {
            alertStack = [alertStack[0]]
        }
    }

    /// Dismisses the entire stack
    public func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.alertStack.removeAll()
            self?.onDismiss?()
        }
    }

    /// Returns the current (top) view in the stack
    public var currentView: RetroAlertStackItem? {
        alertStack.last
    }

    /// Whether we can navigate back
    public var canGoBack: Bool {
        alertStack.count > 1
    }

    /// The number of items in the stack
    public var stackDepth: Int {
        alertStack.count
    }
}

// MARK: - Navigation Stack Container View

/// SwiftUI view that displays the current alert from the navigation stack
public struct RetroAlertNavigationStackView: View {
    @ObservedObject var stack: RetroAlertNavigationStack

    @State private var glowOpacity: Double = 0.7

    public init(stack: RetroAlertNavigationStack) {
        self.stack = stack
    }

    public var body: some View {
        ZStack {
            if stack.isPresented {
                Color.black.opacity(0.85)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onTapGesture {
                        // Optional: dismiss on background tap
                    }

                if let currentItem = stack.currentView {
                    currentItem.view
                        .id(currentItem.id)
                        .transition(transitionForDirection)
                        #if os(tvOS)
                        .onExitCommand {
                            if stack.canGoBack {
                                stack.pop()
                            } else {
                                stack.dismiss()
                            }
                        }
                        #endif
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stack.isPresented)
        .animation(.easeInOut(duration: 0.25), value: stack.currentView?.id)
    }

    private var transitionForDirection: AnyTransition {
        switch stack.navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
}

// MARK: - View Modifier

/// View modifier to attach a RetroAlertNavigationStack to a view
public struct RetroAlertNavigationStackModifier: ViewModifier {
    @ObservedObject var stack: RetroAlertNavigationStack

    public init(stack: RetroAlertNavigationStack) {
        self.stack = stack
    }

    public func body(content: Content) -> some View {
        ZStack {
            content
            RetroAlertNavigationStackView(stack: stack)
                .zIndex(1000)
        }
    }
}

public extension View {
    /// Attaches a RetroAlertNavigationStack to the view
    func retroAlertNavigationStack(_ stack: RetroAlertNavigationStack) -> some View {
        modifier(RetroAlertNavigationStackModifier(stack: stack))
    }
}

// MARK: - Alert Container

/// A container view that provides consistent styling for alerts in the stack
public struct RetroAlertContainer<Content: View>: View {
    private let content: Content
    private let showBackButton: Bool
    private let onBack: (() -> Void)?
    private let onCancel: (() -> Void)?

    @State private var glowOpacity: Double = 0.7

    #if os(tvOS)
    @FocusState private var isCancelFocused: Bool
    #endif

    public init(
        showBackButton: Bool = false,
        onBack: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.showBackButton = showBackButton
        self.onBack = onBack
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            content

            if showBackButton || onCancel != nil {
                HStack(spacing: 16) {
                    if showBackButton, let onBack = onBack {
                        RetroAlertButton(title: "Back", style: .secondary) {
                            onBack()
                        }
                    }

                    if let onCancel = onCancel {
                        RetroAlertButton(title: "Cancel", style: .cancel) {
                            onCancel()
                        }
                        #if os(tvOS)
                        .focused($isCancelFocused)
                        #endif
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 300, maxWidth: 500)
        .background(alertBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alertBorder)
        .shadow(color: Color.retroPink.opacity(glowOpacity), radius: 20, x: 0, y: 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.3
            }
        }
    }

    private var alertBackground: some View {
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
    }

    private var alertBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(
                    gradient: Gradient(colors: [.retroPink, .retroBlue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
    }
}

// MARK: - UIKit Hosting View

/// A SwiftUI view for hosting the navigation stack from UIKit
public struct RetroAlertNavigationStackHostingView: View {
    @ObservedObject var stack: RetroAlertNavigationStack

    public init(stack: RetroAlertNavigationStack) {
        self.stack = stack
    }

    public var body: some View {
        ZStack {
            Color.clear
            RetroAlertNavigationStackView(stack: stack)
        }
        .onAppear {
            if !stack.isPresented {
                stack.isPresented = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RetroAlertNavigationStack_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }

    struct PreviewWrapper: View {
        @StateObject private var stack = RetroAlertNavigationStack()

        var body: some View {
            ZStack {
                Color.gray.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)

                Button("Show Stack") {
                    stack.push(
                        RetroAlertContainer(
                            showBackButton: false,
                            onCancel: { stack.dismiss() }
                        ) {
                            VStack(spacing: 20) {
                                Text("First Alert")
                                    .font(.title)
                                    .foregroundColor(.white)

                                RetroAlertButton(title: "Push Next", style: .primary) {
                                    stack.push(
                                        RetroAlertContainer(
                                            showBackButton: true,
                                            onBack: { stack.pop() },
                                            onCancel: { stack.dismiss() }
                                        ) {
                                            VStack(spacing: 20) {
                                                Text("Second Alert")
                                                    .font(.title)
                                                    .foregroundColor(.white)

                                                Text("You can go back or cancel")
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                            .padding(20)
                                        }
                                    )
                                }
                            }
                            .padding(20)
                        }
                    )
                }
            }
            .retroAlertNavigationStack(stack)
        }
    }
}
#endif
