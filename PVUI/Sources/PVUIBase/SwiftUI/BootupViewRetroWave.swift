//
//  BootupViewRetroWave.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import SwiftUI
import PVUIBase
import PVThemes
import PVLogging
import Combine

public struct BootupViewRetroWave: View {
    @EnvironmentObject public var appState: AppState
    @EnvironmentObject public var themeManager: ThemeManager
    
    @ObservedObject private var iconManager = IconManager.shared
    
    // Accessibility setting for reduce motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation properties
    @State private var glowOpacity: Double = 0.0
    @State private var gridOffset: CGFloat = 1000
    @State private var sunOffset: CGFloat = -200
    @State private var titleScale: CGFloat = 0.8
    @State private var logoGlow: CGFloat = 0.0
    @State private var defaultIcon: UIImage?

    // For the scanning line effect
    @State private var scanlineOffset: CGFloat = 0
    
    // For the blinking text effect
    public let timer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    @State private var showText = true
    
    private var previewImageName: String {
        "\(iconName)-Preview"
    }
    
    private var iconName: String {
        iconManager.currentIconName ?? "AppIcon"
    }
    
    public init() {
        let currentIconName = IconManager.shared.currentIconName
        ILOG("ContentView: App is not initialized, showing BootupView. currentIconName: \(currentIconName ?? "nil")")
        loadDefaultIcon()
        ILOG("BootupViewRetroWave: defaultIcon loaded: \(defaultIcon != nil ? "SUCCESS" : "FAILED")")
    }
    
    @ViewBuilder
    private func iconWrapper(_ uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 120, height: 120)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(
                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 2)
            )
            .shadow(color: Color.retroPink.opacity(logoGlow), radius: 15, x: 0, y: 0)
            .shadow(color: Color.retroBlue.opacity(logoGlow), radius: 15, x: 0, y: 0)
            .scaleEffect(titleScale)
    }
    
    private var fallbackIcon: some View {
        Color.gray.opacity(0.1)
            .frame(width: 120, height: 120)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(
                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 2)
            )
            .shadow(color: Color.retroPink.opacity(logoGlow), radius: 15, x: 0, y: 0)
            .shadow(color: Color.retroBlue.opacity(logoGlow), radius: 15, x: 0, y: 0)
            .scaleEffect(titleScale)
    }
    
    var appName: String {
        // If bundle contains LITE use LITE or use app bundle name?
        let displayName = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? "Provenance"
        return displayName.uppercased()
    }
    
    var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    public var body: some View {
        ZStack {
            // Background color
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Grid background
            BootupRetroGrid(offset: gridOffset)
                .edgesIgnoringSafeArea(.all)
            
            // Sun element
            RetroPurpleSun(offset: sunOffset)
                .edgesIgnoringSafeArea(.all)
            
            // Scanlines effect - only show animation if reduce motion is disabled
            ScanlineEffect(offset: reduceMotion ? 0 : scanlineOffset)
                .edgesIgnoringSafeArea(.all)
                .blendMode(.overlay)
                .opacity(reduceMotion ? 0.05 : 0.15)
            
            // Main content
            VStack(spacing: 30) {
                Spacer()
                Group {
                    if iconName == "AppIcon" || iconName == "" || iconName.lowercased() == "default" {
                        /// Use the default icon from info.plist or fallback
                        if let defaultIcon {
                            iconWrapper(defaultIcon)
                        } else {
                            /// Force fallback to blue preview if defaultIcon is nil
                            if let fallbackIcon = UIImage(named: "AppIcon-Blue-Preview", in: .main, with: nil) {
                                iconWrapper(fallbackIcon)
                            } else {
                                /// Last resort placeholder
                                fallbackIcon
                            }
                        }
                    } else if let uiImage = UIImage(named: previewImageName, in: .main, with: nil) {
                        /// Use preview images for alternate icons
                        iconWrapper(uiImage)
                    } else {
                        /// Fallback placeholder
                        fallbackIcon
                    }
                }
                                
                // Title with neon effect
                Text(appName)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        Text(appName)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .blur(radius: 5)
                            .opacity(glowOpacity)
                    )
                    .shadow(color: .retroPink.opacity(0.8), radius: 5, x: 0, y: 0)
                    .scaleEffect(titleScale)
                
                if let appVersion = appVersion {
                    // Version with neon effect
                    Text(appVersion)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Text(appVersion)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .blur(radius: 5)
                                .opacity(glowOpacity)
                        )
                        .shadow(color: .retroPink.opacity(0.8), radius: 5, x: 0, y: 0)
                        .scaleEffect(titleScale)
                }
                
                // Status text with blinking effect
                Text(appState.bootupStateManager.currentState.localizedDescription)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                    .opacity(showText ? 1.0 : 0.5)
                
                // Custom progress indicator
                ZStack {
                    // Progress bar background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 200, height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ), lineWidth: 1)
                        )
                    
                    // Progress bar glow
                    RetroProgressBar()
                        .frame(width: 200, height: 8)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Footer text
                Text("© 2025 JOSEPH MATTIELLO")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
            }
            .padding()
        }
        .onAppear {
            ILOG("BootupView: Appeared, current state: \(appState.bootupStateManager.currentState.localizedDescription)")
            
            if reduceMotion {
                // If reduce motion is enabled, set final values without animations
                gridOffset = 0
                sunOffset = 0
                titleScale = 1.0
                glowOpacity = 0.5
                logoGlow = 0.3
                scanlineOffset = 0
            } else {
                // Start animations only if reduce motion is disabled
                withAnimation(.easeOut(duration: 2.0)) {
                    gridOffset = 0
                    sunOffset = 0
                    titleScale = 1.0
                }
                
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.7
                    logoGlow = 0.6
                }
                
                // Start scanline animation
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    scanlineOffset = 1000
                }
            }
        }
        .onReceive(timer) { _ in
            // Only animate text blinking if reduce motion is disabled
            if reduceMotion {
                showText = true // Always show text when reduce motion is enabled
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showText.toggle()
                }
            }
        }
    }
    
    /// Load the default app icon from the Info.plist with fallback
    private func loadDefaultIcon() {
        // Try to load from Info.plist first
        if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let iconFileName = iconFiles.last,
           let icon = UIImage(named: iconFileName) {
            self.defaultIcon = icon
            ILOG("BootupViewRetroWave: Successfully loaded default icon from Info.plist: \(iconFileName)")
            return
        }
        
        // Fallback to AppIcon-Blue-Preview if Info.plist method fails
        if let fallbackIcon = UIImage(named: "AppIcon-Blue-Preview", in: .main, with: nil) {
            self.defaultIcon = fallbackIcon
            ILOG("BootupViewRetroWave: Using fallback icon AppIcon-Blue-Preview")
        } else {
            ELOG("BootupViewRetroWave: Failed to load both default icon and fallback icon")
        }
    }
}

#if DEBUG
#Preview {
    BootupViewRetroWave()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
#endif
