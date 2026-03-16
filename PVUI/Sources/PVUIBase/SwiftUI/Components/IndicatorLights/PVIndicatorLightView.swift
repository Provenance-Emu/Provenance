//
//  PVIndicatorLightView.swift
//  PVUIBase
//
//  SwiftUI component for persistent HUD status indicator dots.
//
//  Design:
//    • 8x8pt compact dot mode (default)
//    • Tap/long-press to expand label + description popover
//    • Pulse animation on state change
//    • Color-coded: green, yellow, red, gray, blue
//

import SwiftUI

// MARK: - Individual Light View

/// A single indicator light dot that can expand to show details.
public struct PVIndicatorLightView: View {
    let state: PVIndicatorState
    let onTap: (() -> Void)?

    @State private var isExpanded = false
    @State private var showPopover = false
    @State private var pulseProgress = false

    public init(state: PVIndicatorState, onTap: (() -> Void)? = nil) {
        self.state = state
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            onTap?()
            showPopover = true
        }) {
            indicatorContent
        }
        .buttonStyle(IndicatorButtonStyle())
        .modifier(IndicatorDetailsPresentation(showPopover: $showPopover, state: state))
        .scaleEffect(isExpanded ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isExpanded)
        .onLongPressGesture(minimumDuration: 0.3) {
            withAnimation {
                isExpanded = true
            }
            // Haptic feedback (iOS only — UIImpactFeedbackGenerator unavailable on tvOS)
            #if !os(tvOS)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isExpanded = false
                }
            }
        }
    }

    private var indicatorContent: some View {
        ZStack {
            // Pulsing glow effect — uses a local @State so the animation actually
            // transitions from the initial (scale 1.0 / opacity 1) to final state.
            if state.isPulsing {
                Circle()
                    .fill(state.color.glowColor)
                    .frame(width: 16, height: 16)
                    .scaleEffect(pulseProgress ? 1.5 : 1.0)
                    .opacity(pulseProgress ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 0.6)
                            .repeatCount(1, autoreverses: false),
                        value: pulseProgress
                    )
                    .onAppear { pulseProgress = true }
                    .onDisappear { pulseProgress = false }
            }

            // Main dot
            Circle()
                .fill(state.color.swiftUIColor)
                .frame(width: 8, height: 8)
                .shadow(
                    color: state.color.swiftUIColor.opacity(0.5),
                    radius: state.isPulsing ? 4 : 2,
                    x: 0,
                    y: 0
                )
        }
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
    }
}

// MARK: - Button Style

private struct IndicatorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

private struct IndicatorDetailsPresentation: ViewModifier {
    @Binding var showPopover: Bool
    let state: PVIndicatorState

    func body(content: Content) -> some View {
        #if os(tvOS)
        content
            .sheet(isPresented: $showPopover) {
                IndicatorPopoverView(state: state)
            }
        #else
        content
            .popover(isPresented: $showPopover) {
                IndicatorPopoverView(state: state)
            }
        #endif
    }
}

// MARK: - Popover View

private struct IndicatorPopoverView: View {
    let state: PVIndicatorState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Color dot
                Circle()
                    .fill(state.color.swiftUIColor)
                    .frame(width: 10, height: 10)

                // Label
                Text(state.label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
            }

            Divider()

            // Description
            Text(state.description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(minWidth: 200, maxWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(popoverBackgroundColor)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
    }

    private var popoverBackgroundColor: Color {
        #if os(tvOS)
        return Color.black.opacity(0.9)
        #else
        return Color(.systemBackground)
        #endif
    }
}

// MARK: - Indicator Row View

/// A horizontal row of indicator lights.
public struct PVIndicatorLightRowView: View {
    let indicators: [PVIndicatorState]
    let spacing: CGFloat

    public init(indicators: [PVIndicatorState], spacing: CGFloat = 8) {
        self.indicators = indicators
        self.spacing = spacing
    }

    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(indicators) { indicator in
                PVIndicatorLightView(state: indicator)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.25))
        )
    }
}

// MARK: - Overlay View

/// The full overlay view that displays all active indicators in the HUD.
public struct PVIndicatorOverlayView: View {
    @ObservedObject var registry: PVIndicatorRegistry

    public init(registry: PVIndicatorRegistry = .shared) {
        self.registry = registry
    }

    /// Controls auto-hide fade for the indicator overlay.
    @State private var isVisible: Bool = true

    /// Seconds before the overlay auto-hides.
    private let autoHideDelay: TimeInterval = 5.0

    public var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                if registry.hasVisibleIndicators {
                    PVIndicatorLightRowView(indicators: registry.visibleIndicators)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.bottom, 4)
            .padding(.trailing, 16)
        }
        .opacity(isVisible ? 0.85 : 0.0)
        .animation(.easeInOut(duration: 0.6), value: isVisible)
        .onAppear {
            scheduleAutoHide()
        }
        .onChange(of: registry.visibleIndicators) { _ in
            // Re-show when indicators change state
            withAnimation { isVisible = true }
            scheduleAutoHide()
        }
    }

    @State private var pendingHideWorkItem: DispatchWorkItem?

    private func scheduleAutoHide() {
        guard autoHideDelay > 0 else { return }
        pendingHideWorkItem?.cancel()
        isVisible = true
        let workItem = DispatchWorkItem {
            withAnimation { isVisible = false }
        }
        pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay, execute: workItem)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct PVIndicatorLightView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Individual lights
            HStack(spacing: 20) {
                PVIndicatorLightView(state: PVIndicatorState(
                    id: .jitStatus,
                    color: .green,
                    label: "JIT Active",
                    description: "Performance mode is active"
                ))

                PVIndicatorLightView(state: PVIndicatorState(
                    id: .jitStatus,
                    color: .yellow,
                    label: "Interpreter Mode",
                    description: "Running in compatibility mode"
                ))

                PVIndicatorLightView(state: PVIndicatorState(
                    id: .jitStatus,
                    color: .red,
                    label: "JIT Failed",
                    description: "Could not enable JIT"
                ))
            }

            // Row view
            PVIndicatorLightRowView(indicators: [
                PVIndicatorState(
                    id: .jitStatus,
                    color: .green,
                    label: "JIT Active",
                    description: "Performance mode is active"
                ),
                PVIndicatorState(
                    id: .netplayPing,
                    color: .blue,
                    label: "Netplay",
                    description: "Connected to server"
                )
            ])

            // JIT states
            VStack(spacing: 16) {
                Text("JIT States")
                    .font(.headline)

                HStack(spacing: 20) {
                    PVIndicatorLightView(state: PVJITIndicatorState.active.indicatorState)
                    PVIndicatorLightView(state: PVJITIndicatorState.interpreter.indicatorState)
                    PVIndicatorLightView(state: PVJITIndicatorState.failed.indicatorState)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .previewLayout(.sizeThatFits)
    }
}
#endif
