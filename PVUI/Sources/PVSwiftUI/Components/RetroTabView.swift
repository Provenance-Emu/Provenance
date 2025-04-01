import SwiftUI
import PVUIBase
import PVThemes

/// A custom tab view with retrowave styling
public struct RetroTabView<Content: View>: View {
    @Binding private var selection: Int
    private let content: Content
    private let tabItems: [RetroTabItem]
    
    @State private var localSelection: Int
    @State private var itemFrames: [CGRect] = []
    @State private var tabBarHeight: CGFloat = 60
    @State private var bottomSafeAreaInset: CGFloat = 0
    
    public init(selection: Binding<Int>, @ViewBuilder content: () -> Content, tabItems: [RetroTabItem]) {
        self._selection = selection
        self.content = content()
        self.tabItems = tabItems
        self._localSelection = State(initialValue: selection.wrappedValue)
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Main content area
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, tabBarHeight + bottomSafeAreaInset)
                
                // Custom tab bar
                retroTabBar
                    .frame(height: tabBarHeight + bottomSafeAreaInset)
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                // Calculate bottom safe area inset
                                let window = UIApplication.shared.windows.first
                                bottomSafeAreaInset = window?.safeAreaInsets.bottom ?? 0
                            }
                        }
                    )
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    @State private var borderGlowIntensity: CGFloat = 0.5
    @State private var borderGlowRadius: CGFloat = 0.5
    @State private var borderColorShift: CGFloat = 0
    
    private var retroTabBar: some View {
        ZStack(alignment: .bottom) {
            // Tab bar background with retrowave styling
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.8),
                            RetroTheme.retroDarkBlue.opacity(0.7)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .overlay(
                    // Top border with animated retrowave gradient
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    RetroTheme.retroPink.opacity(borderGlowIntensity),
                                    RetroTheme.retroPurple,
                                    RetroTheme.retroBlue.opacity(borderGlowIntensity)
                                ]),
                                startPoint: UnitPoint(x: borderColorShift, y: 0),
                                endPoint: UnitPoint(x: borderColorShift + 1, y: 0)
                            )
                        )
                        .blur(radius: borderGlowRadius)
                        .padding(.bottom, tabBarHeight - 2),
                    alignment: .top
                )
                .shadow(color: RetroTheme.retroPurple.opacity(0.5), radius: 10, x: 0, y: -5)
            
            // Tab items
            HStack(spacing: 0) {
                ForEach(0..<tabItems.count, id: \.self) { index in
                    tabButton(for: index)
                        .frame(maxWidth: .infinity)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: TabItemPreferenceKey.self,
                                    value: [TabItemPreference(index: index, frame: geo.frame(in: .global))]
                                )
                            }
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, bottomSafeAreaInset + 5)
            .onPreferenceChange(TabItemPreferenceKey.self) { preferences in
                for preference in preferences {
                    if itemFrames.count <= preference.index {
                        itemFrames.append(preference.frame)
                    } else {
                        itemFrames[preference.index] = preference.frame
                    }
                }
            }
            
            // Selection indicator
            if !itemFrames.isEmpty && localSelection < itemFrames.count {
                selectionIndicator
                    .frame(width: tabBarWidth / CGFloat(tabItems.count) - 20)
                    .offset(x: indicatorOffset - (tabBarWidth / CGFloat(tabItems.count)), y: -5) // Shift left by one tab width
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: localSelection)
                    .padding(.bottom, 15) // Move indicator up slightly
            }
        }
        .onChange(of: selection) { newValue in
            localSelection = newValue
            animateBorderOnTabChange()
        }
        .onChange(of: localSelection) { newValue in
            selection = newValue
            animateBorderOnTabChange()
        }
        .onAppear {
            // Start subtle continuous animation
            withAnimation(Animation.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                borderColorShift = 0.5
            }
        }
    }
    
    private func tabButton(for index: Int) -> some View {
        let item = tabItems[index]
        let isSelected = localSelection == index
        
        return Button(action: {
            localSelection = index
        }) {
            VStack(spacing: 4) {
                // Icon
                if let systemName = item.systemImage {
                    Group {
                        if isSelected {
                            Image(systemName: systemName)
                                .font(.system(size: 22))
                                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                                .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 3)
                        } else {
                            Image(systemName: systemName)
                                .font(.system(size: 22))
                                .foregroundColor(Color.white.opacity(0.6))
                                .shadow(color: .clear, radius: 0)
                        }
                    }
                }
                
                // Label
                Group {
                    if isSelected {
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    } else {
                        Text(item.title)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var selectionIndicator: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(RetroTheme.retroHorizontalGradient)
            .frame(height: 3)
            .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                    .blur(radius: 0.5)
                    .offset(y: -1)
            )
    }
    
    private func animateBorderOnTabChange() {
        // Animate border glow intensity
        withAnimation(.easeOut(duration: 0.3)) {
            borderGlowIntensity = 1.0
            borderGlowRadius = 2.0
        }
        
        // Animate color shift
        withAnimation(.easeInOut(duration: 0.5)) {
            borderColorShift = borderColorShift == 0 ? 0.5 : 0
        }
        
        // Return to normal state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                borderGlowIntensity = 0.5
                borderGlowRadius = 0.5
            }
        }
    }
    
    private var tabBarWidth: CGFloat {
        guard let firstFrame = itemFrames.first, let lastFrame = itemFrames.last else {
            return UIScreen.main.bounds.width
        }
        return lastFrame.maxX - firstFrame.minX
    }
    
    private var indicatorOffset: CGFloat {
        guard !itemFrames.isEmpty, localSelection < itemFrames.count else {
            return 0
        }
        
        let selectedFrame = itemFrames[localSelection]
        let firstFrame = itemFrames.first ?? .zero
        
        // Simple calculation to center the indicator under the selected tab
        // Just use the midX of the selected frame relative to the first frame
        return selectedFrame.midX - firstFrame.minX - (tabBarWidth / CGFloat(tabItems.count) / 2)
    }
}

/// Model for a tab item in the RetroTabView
public struct RetroTabItem {
    let title: String
    let systemImage: String?
    
    public init(title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }
}

// MARK: - Preference Key for Tab Item Frames

/// Model to store tab item frame information
struct TabItemPreference: Equatable {
    let index: Int
    let frame: CGRect
}

/// Preference key to collect tab item frames
struct TabItemPreferenceKey: PreferenceKey {
    static var defaultValue: [TabItemPreference] = []
    
    static func reduce(value: inout [TabItemPreference], nextValue: () -> [TabItemPreference]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Previews
struct RetroTabView_Previews: PreviewProvider {
    static var previews: some View {
        RetroTabViewDemo()
    }
    
    struct RetroTabViewDemo: View {
        @State private var selectedTab = 0
        
        var body: some View {
            RetroTabView(
                selection: $selectedTab,
                content: {
                    if selectedTab == 0 {
                        Color.red.opacity(0.3)
                    } else if selectedTab == 1 {
                        Color.blue.opacity(0.3)
                    } else {
                        Color.green.opacity(0.3)
                    }
                },
                tabItems: [
                    RetroTabItem(title: "Games", systemImage: "gamecontroller"),
                    RetroTabItem(title: "Settings", systemImage: "gear"),
                    RetroTabItem(title: "Debug", systemImage: "ladybug")
                ]
            )
        }
    }
}
