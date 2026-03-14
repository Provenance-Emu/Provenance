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
    #if canImport(JITManager)
    @Published public var jitSource: JITSource = .none
    #endif

    /// Whether the current core strictly requires JIT (vs. merely benefiting from it).
    /// Set via `JITStatusIndicatorViewController.updateForCore(id:)` before calling `updateStatus()`.
    public var coreJITIsRequired: Bool = false

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

    #if canImport(JITManager)
    /// Creates a view model with a fixed status and source, useful for previews and testing
    public init(fixedStatus: JITStatus, fixedSource: JITSource) {
        status = fixedStatus
        jitSource = fixedSource
    }
    #endif

    /// Updates the JIT status based on the current JIT manager state.
    ///
    /// When `coreJITIsRequired` is `true` and JIT cannot be acquired, sets `.unavailable`
    /// so the indicator surfaces the "This game requires JIT" guidance message.
    public func updateStatus() {
        #if canImport(JITManager)
        let isJITEnabled = jitManager.appHasAcquiredJit()
        let jitType = jitManager.getJitType()

        if jitType == .none {
            if coreJITIsRequired {
                // JIT subsystem absent and the core needs it — surface guidance message
                status = .unavailable
            } else {
                status = .notApplicable
            }
            jitSource = .none
        } else if isJITEnabled {
            status = .active
            jitSource = jitManager.getJITSource()
        } else if coreJITIsRequired {
            // JIT subsystem present but not acquired, and the core strictly requires it
            status = .unavailable
            jitSource = .none
        } else {
            // JIT subsystem present but not acquired; core only benefits from JIT
            status = .interpreterFallback
            jitSource = .none
        }
        #else
        status = .notApplicable
        #endif
    }

    /// Returns a brief explanation of the current mode (shown in the compact alert on tap).
    /// Includes the JIT acquisition source when active.
    public var explanation: String {
        switch status {
        case .active:
            #if canImport(JITManager)
            let sourceNote = jitSource != .none && jitSource != .unknown
                ? " via \(jitSource.displayName)"
                : ""
            return "JIT compilation active\(sourceNote) — best performance enabled."
            #else
            return "JIT compilation active — best performance enabled."
            #endif
        case .interpreterFallback:
            return "JIT unavailable — some cores may run slower or be unstable."
        case .unavailable:
            return "This game requires JIT to run. Enable JIT via SideJITServer, AltStore, or StikDebug."
        case .notApplicable:
            return ""
        }
    }

    /// Short label shown in the HUD badge.
    /// When JIT is active and a specific source is known, appends the source name.
    public var indicatorLabel: String {
        #if canImport(JITManager)
        guard status == .active, jitSource != .none, jitSource != .unknown else {
            return status.label
        }
        return "JIT · \(jitSource.displayName)"
        #else
        return status.label
        #endif
    }

    /// Accessibility label for the indicator button.
    public var indicatorAccessibilityLabel: String {
        #if canImport(JITManager)
        guard status == .active, jitSource != .none, jitSource != .unknown else {
            return "JIT Status: \(status.label)"
        }
        return "JIT Status: Active via \(jitSource.displayName)"
        #else
        return "JIT Status: \(status.label)"
        #endif
    }

    /// Toggle expanded state
    public func toggleExpanded() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
    }
}

// MARK: - JIT Status Indicator View

/// A small, unobtrusive JIT status indicator for the emulator HUD.
/// Tap the indicator to trigger `onTap`, which the hosting UIViewController
/// uses to present a compact `UIAlertController` — no full-screen sheet.
public struct JITStatusIndicatorView: View {
    @StateObject private var viewModel: JITStatusViewModel
    /// Called when the user taps the indicator pill.  The hosting layer is
    /// responsible for presenting the compact alert (UIAlertController).
    public var onTap: (() -> Void)?

    public init(viewModel: JITStatusViewModel? = nil, onTap: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? JITStatusViewModel())
        self.onTap = onTap
    }

    public var body: some View {
        ZStack {
            if viewModel.status.isVisible {
                Button(action: {
                    onTap?()
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
                .accessibilityHint("Tap to see details about the current emulation mode")
            }
        }
        #if canImport(JITManager)
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
