//
//  RetroSelectionItem.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/7/26.
//

import SwiftUI
import PVThemes

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
