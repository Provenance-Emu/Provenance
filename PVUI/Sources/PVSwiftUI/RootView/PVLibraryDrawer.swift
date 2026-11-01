import SwiftUI
import PVThemes
import PVUIBase

/// Local window geometry drives the panel; resizing never consults a global screen.
enum LibraryDrawerLayout {
    static let edgeWidth: CGFloat = 22
    static let dismissalDistance: CGFloat = 60
    static let shadowOverflow: CGFloat = 40
    static let animation = Animation.spring(response: 0.3, dampingFraction: 0.88)

    static func width(in size: CGSize) -> CGFloat {
        let available = max(0, size.width - 44)
        let preferred = size.width > size.height ? size.width * 0.4 : size.width * 0.78
        return min(available, max(280, min(380, preferred)))
    }

    /// The background extends through side safe areas, including a landscape phone's notch.
    static func hiddenTravel(width: CGFloat, sideInset: CGFloat) -> CGFloat {
        width + shadowOverflow + max(0, sideInset)
    }
}

/// Keeps the library mounted while animating only a panel transform and scrim opacity.
struct PVLibraryDrawer<Content: View, Menu: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: Content
    @ViewBuilder let menu: Menu
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.layoutDirection) private var layoutDirection
    #if !os(tvOS)
    @GestureState(resetTransaction: Transaction(animation: LibraryDrawerLayout.animation)) private var dragTranslation: CGFloat = 0
    #endif

    private var direction: CGFloat { layoutDirection == .leftToRight ? 1 : -1 }
    private var accent: Color { Color(themeManager.currentPalette.defaultTintColor) }

    var body: some View {
        GeometryReader { geometry in
            let width = LibraryDrawerLayout.width(in: geometry.size)
            ZStack(alignment: .leading) {
                content
                    .allowsHitTesting(!isPresented)
                    .accessibilityElement(children: .contain)
                    .accessibilityHidden(isPresented)

                drawerOverlay(width: width, sideInset: max(geometry.safeAreaInsets.leading, geometry.safeAreaInsets.trailing))
                    .animation(reduceMotion ? nil : LibraryDrawerLayout.animation, value: isPresented)

                #if !os(tvOS)
                if !isPresented {
                    Color.clear
                        .frame(width: LibraryDrawerLayout.edgeWidth)
                        .contentShape(Rectangle())
                        .gesture(openGesture(width: width))
                        .accessibilityHidden(true)
                }
                #endif
            }
        }
        .background((Color(themeManager.currentPalette.gameLibraryBackground)).ignoresSafeArea())
        #if os(tvOS)
        .onExitCommand { isPresented = false }
        #endif
    }

    private func drawerOverlay(width: CGFloat, sideInset: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Button {
                isPresented = false
            } label: {
                Color.black.opacity((reduceTransparency ? 0.65 : 0.38) * revealProgress(width: width))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Library Menu")
            .accessibilityHidden(true)
            .allowsHitTesting(isPresented)

            menu
                #if !os(tvOS)
                .disabled(dragTranslation != 0)
                #endif
                .frame(width: width)
                .frame(maxHeight: .infinity)
                .background {
                    Rectangle()
                        .fill(Color(themeManager.currentPalette.menuBackground))
                        .ignoresSafeArea()
                        .shadow(color: .black.opacity(0.45), radius: 18, x: 8 * direction, y: 0)
                }
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(LinearGradient(colors: [accent.opacity(0.15), accent, accent.opacity(0.65), accent.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 1)
                        .shadow(color: accent.opacity(0.6), radius: 4)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                .offset(x: panelOffset(width: width, sideInset: sideInset))
                .opacity(reduceMotion && !isPresented ? 0 : 1)
                .allowsHitTesting(isPresented)
                .accessibilityHidden(!isPresented)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { isPresented = false }
                #if !os(tvOS)
                .simultaneousGesture(closeGesture(width: width))
                #endif
        }
    }

    private func revealProgress(width: CGFloat) -> Double {
        #if !os(tvOS)
        guard width > 0 else { return 0 }
        if isPresented { return 1 }
        return reduceMotion ? 0 : Double(min(1, max(0, dragTranslation * direction / width)))
        #else
        return isPresented ? 1 : 0
        #endif
    }

    private func panelOffset(width: CGFloat, sideInset: CGFloat) -> CGFloat {
        #if !os(tvOS)
        if reduceMotion { return 0 }
        if isPresented {
            return direction * min(0, max(-width, dragTranslation * direction))
        }
        return -direction * LibraryDrawerLayout.hiddenTravel(width: width, sideInset: sideInset) * (1 - revealProgress(width: width))
        #else
        return isPresented ? 0 : -direction * LibraryDrawerLayout.hiddenTravel(width: width, sideInset: sideInset)
        #endif
    }

    #if !os(tvOS)
    private func openGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard value.predictedEndTranslation.width * direction > min(width / 3, LibraryDrawerLayout.dismissalDistance),
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                isPresented = true
            }
    }

    private func closeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.predictedEndTranslation.width * direction < -min(width / 3, LibraryDrawerLayout.dismissalDistance) {
                    isPresented = false
                }
            }
    }
    #endif
}

/// Observes menu visibility at the shell boundary, without invalidating library data views.
struct PVLibraryDrawerHost<Content: View, Menu: View>: View {
    @ObservedObject private var drawerState: LibraryDrawerState
    @ObservedObject private var viewModel: PVRootViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder let content: Content
    @ViewBuilder let menu: Menu

    init(viewModel: PVRootViewModel, @ViewBuilder content: () -> Content, @ViewBuilder menu: () -> Menu) {
        self.viewModel = viewModel
        drawerState = viewModel.drawerState
        self.content = content()
        self.menu = menu()
    }

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                if !viewModel.isSidebarCollapsed {
                    menu
                        .frame(width: 224)
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(Color.retroBlue.opacity(0.3)).frame(width: 1)
                        }
                }
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            overlayDrawer
        }
        #else
        overlayDrawer
        #endif
    }

    private var overlayDrawer: some View {
        PVLibraryDrawer(isPresented: $drawerState.isPresented) {
            content
        } menu: {
            menu
        }
    }
}
