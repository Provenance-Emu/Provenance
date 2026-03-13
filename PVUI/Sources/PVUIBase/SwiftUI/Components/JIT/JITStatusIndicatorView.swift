//
//  JITStatusIndicatorView.swift
//  PVUIBase
//
//  JIT status indicator for the emulator HUD.
//  Part of issue #2796.
//

import SwiftUI
import PVSettings
import PVThemes
#if canImport(JITManager)
import JITManager
#endif
#if canImport(PVJIT)
import PVJIT
#endif

// MARK: - JIT Status Types

/// Represents the current JIT status for display in the HUD
public enum JITStatus: Equatable {
    /// JIT is active and running (green dot)
    case active
    /// Running in interpreter fallback mode (yellow dot)
    case interpreterFallback
    /// JIT is required but unavailable (red dot)
    case unavailable
    /// JIT is not applicable for this core (hidden)
    case notApplicable

    public var iconColor: Color {
        switch self {
        case .active:
            return Color.green
        case .interpreterFallback:
            return Color.yellow
        case .unavailable:
            return Color.red
        case .notApplicable:
            return Color.clear
        }
    }

    public var label: String {
        switch self {
        case .active:
            return "JIT Active"
        case .interpreterFallback:
            return "Compatibility Mode"
        case .unavailable:
            return "JIT Unavailable"
        case .notApplicable:
            return ""
        }
    }

    public var isVisible: Bool {
        self != .notApplicable
    }
}

// MARK: - View Model

/// View model for the JIT status indicator
@MainActor
public final class JITStatusViewModel: ObservableObject {
    @Published public var status: JITStatus = .notApplicable
    @Published public var isExpanded: Bool = false
    /// The detected JIT acquisition source (e.g. AltStore, StikDebug, TrollStore).
    @Published public var jitSource: JITSource = .none

    #if canImport(JITManager)
    private var jitManager: DOLJitManager { DOLJitManager.shared }
    #endif

    public init() {
        updateStatus()
    }

    /// Creates a view model with a fixed status, useful for previews and testing
    public init(fixedStatus: JITStatus) {
        status = fixedStatus
    }

    /// Creates a view model with a fixed status and source, useful for previews and testing
    public init(fixedStatus: JITStatus, fixedSource: JITSource) {
        status = fixedStatus
        jitSource = fixedSource
    }

    /// Updates the JIT status based on the current JIT manager state
    public func updateStatus() {
        #if canImport(JITManager)
        let isJITEnabled = jitManager.appHasAcquiredJit()
        let jitType = jitManager.getJitType()

        if jitType == .none {
            status = .notApplicable
            jitSource = .none
        } else if isJITEnabled {
            status = .active
            jitSource = jitManager.getJITSource()
        } else {
            // For now, show as interpreter fallback
            // TODO: Update when JIT Capability Matrix (#2793) is implemented
            // to distinguish between "interpreter fallback" vs "JIT required but failed"
            status = .interpreterFallback
            jitSource = .none
        }
        #else
        status = .notApplicable
        jitSource = .none
        #endif
    }

    /// Returns a brief explanation of the current mode, including the JIT source when active.
    public var explanation: String {
        switch status {
        case .active:
            let sourceNote = jitSource != .none && jitSource != .unknown
                ? " via \(jitSource.displayName)"
                : ""
            return "JIT compilation is active\(sourceNote), providing full-speed emulation with dynamic recompilation."
        case .interpreterFallback:
            return "Running in interpreter mode. Emulation may be slower. Connect to a debugger or use AltJIT to enable JIT."
        case .unavailable:
            return "JIT is required for this core but could not be acquired. Performance will be significantly reduced."
        case .notApplicable:
            return ""
        }
    }

    /// Short label shown in the HUD badge.
    /// When JIT is active and a specific source is known, appends the source name.
    public var indicatorLabel: String {
        guard status == .active, jitSource != .none, jitSource != .unknown else {
            return status.label
        }
        return "JIT · \(jitSource.displayName)"
    }

    /// Accessibility label for the indicator button.
    public var indicatorAccessibilityLabel: String {
        guard status == .active, jitSource != .none, jitSource != .unknown else {
            return "JIT Status: \(status.label)"
        }
        return "JIT Status: Active via \(jitSource.displayName)"
    }

    /// Toggle expanded state
    public func toggleExpanded() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
    }
}

// MARK: - JIT Explanation Popover

/// Compact popover content showing the JIT status explanation
private struct JITExplanationPopoverView: View {
    let status: JITStatus
    let jitSource: JITSource
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(status.iconColor)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.label)
                        .font(.headline)
                    if status == .active, jitSource != .none, jitSource != .unknown {
                        Text("via \(jitSource.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Text(explanation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: 280)
    }
}

// MARK: - JIT Status Indicator View

/// A small, unobtrusive JIT status indicator for the emulator HUD
public struct JITStatusIndicatorView: View {
    @StateObject private var viewModel: JITStatusViewModel
    @State private var showExplanation: Bool = false

    public init(viewModel: JITStatusViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? JITStatusViewModel())
    }

    public var body: some View {
        ZStack {
            if viewModel.status.isVisible {
                // Main indicator button — tap shows a compact popover, not a cover sheet
                Button(action: {
                    showExplanation.toggle()
                }) {
                    HStack(spacing: 8) {
                        // Status dot
                        Circle()
                            .fill(viewModel.status.iconColor)
                            .frame(width: 10, height: 10)
                            .shadow(color: viewModel.status.iconColor.opacity(0.6), radius: 4, x: 0, y: 0)

                        // Label — shows source name (e.g. "JIT · AltStore") when active and source is known
                        Text(viewModel.indicatorLabel)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.75))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(viewModel.status.iconColor.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(viewModel.indicatorAccessibilityLabel)
                .accessibilityHint("Tap to show details about the current emulation mode")
                #if !os(tvOS)
                .popover(isPresented: $showExplanation, arrowEdge: .top) {
                    JITExplanationPopoverView(
                        status: viewModel.status,
                        jitSource: viewModel.jitSource,
                        explanation: viewModel.explanation
                    )
                    .presentationCompactAdaptation(.popover)
                }
                #else
                // TODO: A tvOS version of the JIT popover?
                #endif
            }
        }
        #if canImport(PVJIT)
        .onReceive(NotificationCenter.default.publisher(for: .DOLJitAcquired)) { _ in
            viewModel.updateStatus()
        }
        #endif
    }
}

// MARK: - Preview

#if DEBUG
struct JITStatusIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                // Active state preview with injected view model
                JITStatusIndicatorView(viewModel: JITStatusViewModel(fixedStatus: .active))

                // Individual state previews
                JITStatusIndicatorPreview(status: .active)
                JITStatusIndicatorPreview(status: .interpreterFallback)
                JITStatusIndicatorPreview(status: .unavailable)
            }
        }
    }
}

struct JITStatusIndicatorPreview: View {
    let status: JITStatus

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.iconColor)
                .frame(width: 10, height: 10)

            Text(status.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(status.iconColor.opacity(0.5), lineWidth: 1)
                )
        )
    }
}
#endif
