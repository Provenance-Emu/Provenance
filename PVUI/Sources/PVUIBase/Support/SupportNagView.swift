//
//  SupportNagView.swift
//  PVUIBase
//
//  Created by AI Assistant
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// MARK: - Feature Card

/// A single feature card for the nag screen
private struct PlusFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.retroPink, .retroPurple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// A retrowave-styled nag screen that appears periodically to encourage users to support the project
public struct SupportNagView: View {
    @Environment(\.dismiss) private var dismiss

    let gameLaunchCount: Int
    let onDismiss: () -> Void

    public init(gameLaunchCount: Int, onDismiss: @escaping () -> Void = {}) {
        self.gameLaunchCount = gameLaunchCount
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Retrowave background
            Color.retroBlack
                .ignoresSafeArea()

            // Grid overlay
            RetroTheme.RetroGridView()
                .opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Animated icon
                ZStack {
                    // Glowing circle background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.retroPink.opacity(0.3),
                                    Color.retroPurple.opacity(0.3),
                                    Color.retroBlue.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                        .opacity(glowOpacity)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                            value: glowOpacity
                        )

                    // Icon circle
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )

                    Image(systemName: "star.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Title
                Text("UNLOCK ALL FEATURES")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)

                // Subtitle
                Text("You've launched \(gameLaunchCount) games — upgrade to get the most out of Provenance!")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Feature cards
                VStack(spacing: 0) {
                    PlusFeatureCard(
                        icon: "icloud",
                        title: "Cloud Sync",
                        subtitle: "Sync saves, ROMs & BIOS across devices"
                    )

                    Divider().background(Color.retroPurple.opacity(0.3))

                    PlusFeatureCard(
                        icon: "paintpalette",
                        title: "Premium Themes",
                        subtitle: "9 CGA colors + RetroWave theme"
                    )

                    Divider().background(Color.retroPurple.opacity(0.3))

                    PlusFeatureCard(
                        icon: "app.badge",
                        title: "Custom App Icons",
                        subtitle: "15+ exclusive icon designs"
                    )

                    Divider().background(Color.retroPurple.opacity(0.3))

                    PlusFeatureCard(
                        icon: "gearshape.2",
                        title: "Advanced Controls",
                        subtitle: "Power user settings & configurations"
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.retroPink.opacity(0.5),
                                            Color.retroPurple.opacity(0.5),
                                            Color.retroBlue.opacity(0.5)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                // Buttons
                VStack(spacing: 16) {
                    // Support button
                    #if canImport(FreemiumKit)
                    PaidFeatureView {
                        supportButton
                    } lockedView: {
                        supportButton
                    }
                    .freemiumKitColorReset()
                    #endif

                    // Dismiss button - appears after delay
                    if showDismiss {
                        Button(action: {
                            #if !os(tvOS)
                            HapticFeedbackService.shared.playSelection()
                            #endif
                            SupportNagManager.recordDismissal()
                            onDismiss()
                            dismiss()
                        }) {
                            Text("Maybe Later")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer()
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            glowOpacity = 1.0
            // Delay showing dismiss button by 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeIn(duration: 0.3)) {
                    showDismiss = true
                }
            }
        }
    }

    private var supportButton: some View {
        Button(action: {
            #if !os(tvOS)
            HapticFeedbackService.shared.playSuccess()
            #endif
        }) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Unlock All Features")
                    .font(.system(size: 18, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @State private var glowOpacity: Double = 0.5
    @State private var showDismiss: Bool = false
}

#if DEBUG
struct SupportNagView_Previews: PreviewProvider {
    static var previews: some View {
        SupportNagView(gameLaunchCount: 25) {
            print("Dismissed")
        }
    }
}
#endif
