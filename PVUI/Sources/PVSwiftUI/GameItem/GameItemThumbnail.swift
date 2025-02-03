//
//  GameItemThumbnail.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes
import PVMediaCache
import CoreMotion

struct GameItemThumbnail: View {
    var artwork: SwiftImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio
    let radius: CGFloat = 3.0

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var motionManager = CMMotionManager()
    @State private var roll: Double = 0
    @State private var pitch: Double = 0
    @State private var isHovered: Bool = false
    @State private var viewPosition: CGPoint = .zero
    @State private var screenCenter: CGPoint = .zero
    @State private var positionAngle: Double = 0

    private let glintWidth: CGFloat = 400
    private let glintHeight: CGFloat = 400

    var body: some View {
        Group {
            if let artwork = artwork {
                ZStack {
                    // Main artwork with scaling
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(isHovered ? 1.02 : 1.0)
                        .animation(.easeOut(duration: 0.2), value: isHovered)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        // Get the view's position in the global coordinate space
                                        let frame = geometry.frame(in: .global)
                                        viewPosition = CGPoint(x: frame.midX, y: frame.midY)
                                        calculatePositionAngle()
                                    }
                                    .onChange(of: geometry.frame(in: .global)) { frame in
                                        viewPosition = CGPoint(x: frame.midX, y: frame.midY)
                                        calculatePositionAngle()
                                    }
                            }
                        )

                    // Effects container (clipped to cell bounds)
                    ZStack {
                        // Subtle vignette
                        RoundedRectangle(cornerRadius: radius)
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 200
                                )
                            )
                            .blendMode(.multiply)

                        // Glossy overlay
                        RoundedRectangle(cornerRadius: radius)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .white.opacity(0.15),
                                        .white.opacity(0.05),
                                        .clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.overlay)

                        // Dynamic glint effect
                        RoundedRectangle(cornerRadius: radius)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.5), location: 0.2),
                                        .init(color: .white.opacity(0.3), location: 0.4),
                                        .init(color: .clear, location: 0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: glintWidth, height: glintHeight)
                            .rotationEffect(.degrees(45 + roll * 15 + positionAngle * 10))
                            .offset(
                                x: CGFloat(pitch * 30 + positionAngle * 5) + (isHovered ? 20 : 0),
                                y: CGFloat(roll * 30 + positionAngle * 5) + (isHovered ? 20 : 0)
                            )
                            .blendMode(.screen)
                            .opacity(isHovered ? 1 : 0.5)
                            .animation(.easeInOut(duration: 0.3), value: isHovered)
                    }
                    .clipped() // Clip effects to cell bounds
                }
            } else {
                /// Fallback to text-based artwork with the specified aspect ratio
                ArtworkImageBaseView(artwork: artwork, gameTitle: gameTitle, boxartAspectRatio: boxartAspectRatio)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.5), lineWidth: 1)
        )
        .background(GeometryReader { geometry in
            Color.clear.preference(
                key: ArtworkDynamicWidthPreferenceKey.self,
                value: geometry.size.width
            )
        })
        .cornerRadius(radius)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            startMotionUpdates()
        }
        .onDisappear {
            stopMotionUpdates()
        }
    }

    private func calculatePositionAngle() {
        // Calculate the angle based on the view's position relative to screen center
        let dx = viewPosition.x - screenCenter.x
        let dy = viewPosition.y - screenCenter.y
        positionAngle = atan2(dy, dx) * 180 / .pi
    }

    private func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { (data, error) in
                guard let data = data else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    self.roll = data.attitude.roll
                    self.pitch = data.attitude.pitch
                }
            }
        }

        // Get screen center on first appearance
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                screenCenter = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}
