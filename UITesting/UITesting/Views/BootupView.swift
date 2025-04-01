//
//  BootupView.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import SwiftUI
import PVSwiftUI
import PVUIBase
import PVThemes
import PVLogging
import Combine

struct BootupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    // Animation properties
    @State private var glowOpacity: Double = 0.0
    @State private var gridOffset: CGFloat = 1000
    @State private var sunOffset: CGFloat = -200
    @State private var titleScale: CGFloat = 0.8
    @State private var logoGlow: CGFloat = 0.0
    
    // For the scanning line effect
    @State private var scanlineOffset: CGFloat = 0
    
    // For the blinking text effect
    let timer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    @State private var showText = true
    
    init() {
        ILOG("ContentView: App is not initialized, showing BootupView")
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Grid background
            BootupRetroGrid(offset: gridOffset)
                .edgesIgnoringSafeArea(.all)
            
            // Sun element
            RetroPurpleSun(offset: sunOffset)
                .edgesIgnoringSafeArea(.all)
            
            // Scanlines effect
            ScanlineEffect(offset: scanlineOffset)
                .edgesIgnoringSafeArea(.all)
                .blendMode(.overlay)
                .opacity(0.15)
            
            // Main content
            VStack(spacing: 30) {
                Spacer()
                
                // App icon with glow effect
                Image("AppIcon")
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
                
                // Title with neon effect
                Text("PROVENANCE")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        Text("PROVENANCE")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .blur(radius: 5)
                            .opacity(glowOpacity)
                    )
                    .shadow(color: .retroPink.opacity(0.8), radius: 5, x: 0, y: 0)
                    .scaleEffect(titleScale)
                
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
                Text("© 2025 PROVENANCE TEAM")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
            }
            .padding()
        }
        .onAppear {
            ILOG("BootupView: Appeared, current state: \(appState.bootupStateManager.currentState.localizedDescription)")
            
            // Start animations
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
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showText.toggle()
            }
        }
    }
}

// MARK: - Color Extensions
extension Color {
    static let retroPink = Color(red: 0.99, green: 0.11, blue: 0.55)
    static let retroPurple = Color(red: 0.53, green: 0.11, blue: 0.91)
    static let retroBlue = Color(red: 0.0, green: 0.75, blue: 0.95)
}

#Preview {
    BootupView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
