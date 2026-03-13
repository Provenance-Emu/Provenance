//
//  PVToastView.swift
//  PVUI
//
//  Created by Claude on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

// MARK: - Toast Model

/// A single toast notification item
public struct PVToast: Identifiable, Sendable {
    public let id: String
    public let message: String
    public let type: PVToastType
    public let icon: String
    public let duration: TimeInterval
    public let isPersistent: Bool

    init(
        id: String = UUID().uuidString,
        message: String,
        type: PVToastType = .info,
        icon: String? = nil,
        duration: TimeInterval = 3.0,
        isPersistent: Bool = false
    ) {
        self.id = id
        self.message = message
        self.type = type
        self.icon = icon ?? type.defaultIcon
        self.duration = duration
        self.isPersistent = isPersistent
    }
}

// MARK: - Individual Toast Item View

/// A single toast notification row with retrowave styling
struct PVToastItemView: View {
    let toast: PVToast
    let onDismiss: () -> Void

    @State private var glowOpacity: Double = 0.6

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .foregroundColor(toast.type.color)
                .font(.system(size: 16, weight: .semibold))
                .shadow(color: toast.type.color.opacity(glowOpacity), radius: 4)
                .accessibilityHidden(true)

            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            if !toast.isPersistent {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(RetroTheme.retroPurple.opacity(0.8))
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Dismiss notification")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [toast.type.color, RetroTheme.retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: toast.type.color.opacity(0.4), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(toast.type.accessibilityLabel): \(toast.message)")
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}

// MARK: - Toast Position

/// Anchor position for the toast stack overlay
public enum PVToastPosition: Sendable {
    case top
    case bottomCenter
    case bottomLeft
    case bottomRight

    var alignment: Alignment {
        switch self {
        case .top:          return .top
        case .bottomCenter: return .bottom
        case .bottomLeft:   return .bottomLeading
        case .bottomRight:  return .bottomTrailing
        }
    }

    var edgePadding: EdgeInsets {
        switch self {
        case .top:
            return EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16)
        case .bottomCenter:
            return EdgeInsets(top: 0, leading: 16, bottom: 24, trailing: 16)
        case .bottomLeft:
            return EdgeInsets(top: 0, leading: 16, bottom: 24, trailing: 64)
        case .bottomRight:
            return EdgeInsets(top: 0, leading: 64, bottom: 24, trailing: 16)
        }
    }
}

// MARK: - Toast Stack View

/// Renders the entire queue of toast notifications as a stacked overlay.
/// Intended to be placed at the top of the view hierarchy (above the emulator).
public struct PVToastStackView: View {
    @ObservedObject private var manager = PVToastManager.shared

    public var position: PVToastPosition = .bottomCenter

    public init(position: PVToastPosition = .bottomCenter) {
        self.position = position
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: position.alignment) {
                Color.clear
                VStack(spacing: 8) {
                    ForEach(manager.toasts) { toast in
                        PVToastItemView(toast: toast) {
                            manager.dismiss(id: toast.id)
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: position == .top ? .top : .bottom)
                                    .combined(with: .opacity),
                                removal: .scale(scale: 0.85)
                                    .combined(with: .opacity)
                            )
                        )
                    }
                }
                .padding(position.edgePadding)
                .frame(maxWidth: min(geo.size.width, 480))
            }
        }
        .allowsHitTesting(true)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.toasts.map(\.id))
    }
}

#if DEBUG
#Preview("Toast Stack") {
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.15)
            .ignoresSafeArea()

        PVToastStackView(position: .bottomCenter)
    }
    .onAppear {
        PVToastManager.shared.show("ROM loaded successfully", type: .success)
        PVToastManager.shared.show("Save state created", type: .info)
        PVToastManager.shared.show("JIT enabled — faster emulation active", type: .jit)
        PVToastManager.shared.show("Achievement unlocked: Speed Runner", type: .achievement, icon: "trophy.fill")
    }
}
#endif
