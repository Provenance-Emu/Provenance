///
/// ControllerGuideCardView.swift
/// PVUI
///
/// Compact card recommending hardware controllers, shown in empty-library views.
/// Tapping it presents ControllerGuideDetailView as a sheet.
///

import SwiftUI
import PVThemes

/// A compact, dismissible card that surfaces the controller pairing guide
/// from any empty-library context.
public struct ControllerGuideCardView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var showDetail = false
    @State private var dismissed = false

    private static let dismissedKey = "PVControllerGuideCardDismissed"

    public init() {}

    public var body: some View {
        if !dismissed {
            cardContent
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .sheet(isPresented: $showDetail) {
                    ControllerGuideDetailView()
                }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 10) {
            headerRow
            descriptionText
            actionRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentPalette.gameLibraryBackground.swiftUIColor.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .retroBlue.opacity(0.35), radius: 6, x: 0, y: 0)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "gamecontroller.fill")
                .foregroundColor(.retroBlue)
            Text("Pair a Controller")
                .font(.headline)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            Spacer()
            Button {
                withAnimation {
                    dismissed = true
                    UserDefaults.standard.set(true, forKey: Self.dismissedKey)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss controller guide")
        }
    }

    private var descriptionText: some View {
        Text("Play with a physical gamepad for the best experience. Bluetooth MFi, PS4/PS5, and Xbox controllers are all supported.")
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionRow: some View {
        HStack {
            Button {
                showDetail = true
            } label: {
                Text("View Pairing Guide")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 32)
            }
            .buttonStyle(.plain)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .retroBlue.opacity(0.35), radius: 4, x: 0, y: 2)

            Spacer()
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.retroDarkBlue.ignoresSafeArea()
        ControllerGuideCardView()
            .padding()
    }
}
#endif
