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

            VStack(spacing: 24) {
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
                        .frame(width: 120, height: 120)
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
                        .frame(width: 100, height: 100)
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

                    Image(systemName: "heart.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.bottom, 8)

                // Title
                Text("YOU'RE AN ACTIVE USER!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)

                // Stats
                VStack(spacing: 8) {
                    Text("You've launched \(gameLaunchCount) games!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Thanks for being part of the Provenance community")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Message
                VStack(spacing: 12) {
                    Text("Support Provenance Plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Help us continue developing and improving Provenance by subscribing to Provenance Plus. Get access to premium features and support the project!")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
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
                .padding(.horizontal, 24)

                // Buttons
                VStack(spacing: 16) {
                    // Support button
                    #if canImport(FreemiumKit)
                    PaidFeatureView {
                        Button(action: {
                            #if !os(tvOS)
                            HapticFeedbackService.shared.playSuccess()
                            #endif
                            // PaidFeatureView will handle showing paywall when user taps
                        }) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Support Provenance Plus")
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
                    } lockedView: {
                        Button(action: {
                            #if !os(tvOS)
                            HapticFeedbackService.shared.playSuccess()
                            #endif
                            // PaidFeatureView will handle showing paywall when user taps
                        }) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Support Provenance Plus")
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
                    .freemiumKitColorReset()
                    #endif

                    // Dismiss button
                    Button(action: {
                        #if !os(tvOS)
                        HapticFeedbackService.shared.playSelection()
                        #endif
                        onDismiss()
                        dismiss()
                    }) {
                        Text("Maybe Later")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            glowOpacity = 1.0
        }
    }

    @State private var glowOpacity: Double = 0.5
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
