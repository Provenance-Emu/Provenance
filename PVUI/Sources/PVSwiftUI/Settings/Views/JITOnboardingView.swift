//
//  JITOnboardingView.swift
//  PVUI
//
//  Created by Provenance on 3/10/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Apple-safe JIT onboarding screen that explains "Performance Mode" to users
//  without triggering App Store rejection or violating guidelines.
//

import SwiftUI
import PVThemes
import PVSettings

/// Apple-safe JIT onboarding view that explains "Performance Mode" to users
/// without using words like "jailbreak" or implying App Store policy circumvention.
@available(iOS 14.0, tvOS 14.0, *)
public struct JITOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// The core category identifier for tracking "shown" state
    let coreCategory: String

    /// The display name of the core (e.g., "Dolphin", "PPSSPP")
    let coreName: String

    /// Optional callback when user chooses to enable Performance Mode
    let onEnablePerformanceMode: () -> Void

    /// Optional callback when user chooses compatibility mode
    let onContinueWithoutJIT: () -> Void

    /// Whether the view is currently showing the JIT wait/activation UI
    @State private var isActivatingJIT = false

    /// Whether to show the "Don't ask again" checkbox
    @State private var dontAskAgain = false

    public init(
        coreCategory: String,
        coreName: String,
        onEnablePerformanceMode: @escaping () -> Void,
        onContinueWithoutJIT: @escaping () -> Void
    ) {
        self.coreCategory = coreCategory
        self.coreName = coreName
        self.onEnablePerformanceMode = onEnablePerformanceMode
        self.onContinueWithoutJIT = onContinueWithoutJIT
    }

    public var body: some View {
        ZStack {
            // Background
            RetroTheme.retroBackground
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 24) {
                    // Icon header
                    iconHeader

                    // Title
                    titleSection

                    // Explanation cards
                    explanationSection

                    // Action buttons
                    actionButtons

                    // Footer options
                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .overlay(activationOverlay)
    }

    // MARK: - Icon Header

    private var iconHeader: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [RetroTheme.retroPink.opacity(0.3), RetroTheme.retroPurple.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 120, height: 120)
                .blur(radius: 4)

            // Main circle background
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            RetroTheme.retroPurple.opacity(0.2),
                            RetroTheme.retroPink.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )

            // Lightning bolt icon
            Image(systemName: "bolt.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: RetroTheme.retroPink.opacity(0.6), radius: 8)
        }
        .padding(.top, 20)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Performance Mode")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: RetroTheme.retroPink.opacity(0.4), radius: 4)

            Text("\(coreName) runs significantly faster with Performance Mode.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Explanation Section

    private var explanationSection: some View {
        VStack(spacing: 16) {
            // What is Performance Mode?
            explanationCard(
                icon: "cpu",
                title: "What is Performance Mode?",
                description: "Performance Mode uses advanced CPU features to emulate games at full speed with better compatibility."
            )

            // How to enable
            explanationCard(
                icon: "gear.badge.checkmark",
                title: "How to Enable",
                description:
                    "Performance Mode requires a debugger-based helper to attach to Provenance. " +
                    "If you use SideStore, StikDebug, AltStore, or developer tools, " +
                    "tap Enable below and finish the helper flow."
            )

            // Compatibility mode note
            explanationCard(
                icon: "tortoise",
                title: "Compatibility Mode",
                description: "Without Performance Mode, games may run slower or have compatibility issues. You can continue in Compatibility Mode, but the experience may be degraded."
            )
        }
    }

    private func explanationCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(RetroTheme.retroPurple.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(RetroTheme.retroBlue)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPurple.opacity(0.5), RetroTheme.retroPink.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Enable Performance Mode button
            Button(action: {
                saveDontAskPreference()
                isActivatingJIT = true
                onEnablePerformanceMode()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .bold))

                    Text("Enable Performance Mode")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: RetroTheme.retroPink.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Continue in Compatibility Mode button
            Button(action: {
                saveDontAskPreference()
                onContinueWithoutJIT()
                dismiss()
            }) {
                Text("Continue in Compatibility Mode")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(RetroTheme.retroBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(RetroTheme.retroPurple.opacity(0.5), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(RetroTheme.retroPurple.opacity(0.1))
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 16) {
            // Don't ask again toggle
            Button(action: {
                dontAskAgain.toggle()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: dontAskAgain ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            dontAskAgain ?
                            AnyShapeStyle(LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                startPoint: .top,
                                endPoint: .bottom
                            )) :
                            AnyShapeStyle(Color.gray.opacity(0.5))
                        )

                    Text("Don't ask again for this system")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 4)

            // Learn More link
            Button(action: {
                // Open in-app FAQ or help (not external jailbreak sites)
                if let url = URL(string: "https://wiki.provenance-emu.com/faq#performance-mode") {
                    openURL(url)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))

                    Text("Learn More")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, 8)
    }

    // MARK: - Activation Overlay

    @ViewBuilder
    private var activationOverlay: some View {
        if isActivatingJIT {
            ZStack {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RetroTheme.retroPink))
                        .scaleEffect(1.5)

                    Text("Activating Performance Mode...")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Please wait while we connect a debugger-based helper such as SideStore or StikDebug for better performance.")
                        .font(.system(size: 14))
                        .foregroundColor(RetroTheme.retroBlue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPink.opacity(0.5), RetroTheme.retroPurple.opacity(0.5)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func saveDontAskPreference() {
        if dontAskAgain {
            // Track that user doesn't want to see this again for this core category
            var dismissedCategories = Defaults[.jitOnboardingDismissedCategories]
            dismissedCategories.insert(coreCategory)
            Defaults[.jitOnboardingDismissedCategories] = dismissedCategories
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 14.0, tvOS 14.0, *)
struct JITOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        JITOnboardingView(
            coreCategory: "dolphin",
            coreName: "Dolphin",
            onEnablePerformanceMode: {},
            onContinueWithoutJIT: {}
        )
    }
}
#endif
