#if canImport(SwiftUI)
import SwiftUI
import PVThemes

/// Full-width retrowave-styled floating toolbar for multi-select batch actions.
/// Rendered at the root overlay level (above the tab bar) by `RetroMainView`.
public struct RetroMultiSelectToolbar: View {
    @ObservedObject private var state = MultiSelectToolbarState.shared
    @State private var glowPhase: CGFloat = 0

    public init() {}

    public var body: some View {
        if state.isActive {
            VStack(spacing: 0) {
                Spacer()
                toolbarContent
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.isActive)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var toolbarContent: some View {
        VStack(spacing: 0) {
            // Animated neon top border
            topBorder

            // Main bar content
            HStack(spacing: 14) {
                selectionBadge
                Spacer()
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, max(14, bottomSafeInset))
            .background(barBackground)
        }
        .shadow(color: Color.retroPink.opacity(0.3), radius: 20, x: 0, y: -8)
    }

    // MARK: - Top border

    private var topBorder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.retroPink.opacity(0.8),
                        Color.retroPurple.opacity(0.6),
                        Color.retroBlue.opacity(0.8)
                    ],
                    startPoint: UnitPoint(x: glowPhase, y: 0),
                    endPoint: UnitPoint(x: glowPhase + 1, y: 0)
                )
            )
            .frame(height: 2)
            .blur(radius: 0.5)
            .shadow(color: Color.retroPink.opacity(0.6), radius: 6, x: 0, y: -2)
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: true)) {
                    glowPhase = 0.5
                }
            }
    }

    // MARK: - Selection badge

    private var selectionBadge: some View {
        HStack(spacing: 8) {
            // Glowing count circle
            ZStack {
                Circle()
                    .fill(Color.retroPink.opacity(0.2))
                    .frame(width: 32, height: 32)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.retroPink, .retroPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 32, height: 32)
                Text("\(state.selectedCount)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
            }
            .shadow(color: Color.retroPink.opacity(0.4), radius: 4)

            Text(state.selectedCount == 0 ? "Select Games" : "Selected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .tracking(0.5)
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Normalize titles
            Button {
                state.onNormalizeTitles?()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "textformat.abc")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Normalize")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.retroBlue.opacity(state.selectedCount > 0 ? 0.15 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    Color.retroBlue.opacity(state.selectedCount > 0 ? 0.6 : 0.2),
                                    lineWidth: 1
                                )
                        )
                )
                .foregroundColor(state.selectedCount > 0 ? .retroBlue : .white.opacity(0.3))
            }
            .disabled(state.selectedCount == 0)

            // Done
            Button {
                state.onDone?()
            } label: {
                Text("Done")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.retroPink, .retroPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundColor(.white)
                    .shadow(color: Color.retroPink.opacity(0.4), radius: 6)
            }
        }
    }

    // MARK: - Background

    private var barBackground: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.04, blue: 0.14),
                        Color(red: 0.04, green: 0.03, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Safe area

    private var bottomSafeInset: CGFloat {
        #if canImport(UIKit) && !os(tvOS)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.bottom ?? 0
        #else
        0
        #endif
    }
}

#if DEBUG
#Preview("Multi-Select Toolbar") {
    ZStack {
        Color.retroBlack.ignoresSafeArea()
        RetroMultiSelectToolbar()
    }
    .onAppear {
        let state = MultiSelectToolbarState.shared
        state.isActive = true
        state.selectedCount = 3
    }
}
#endif
#endif
