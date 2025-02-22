//
//  HomeContinueItemView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

import SwiftUI
import PVThemes
import RealmSwift

struct HomeContinueItemView: SwiftUI.View {

    @ObservedRealmObject var continueState: PVSaveState
    @ObservedObject private var themeManager = ThemeManager.shared
    let height: CGFloat
    let hideSystemLabel: Bool
    var action: () -> Void
    let isFocused: Bool

    @State private var showDeleteAlert = false

    /// Constants for CRT effects
    private enum CRTEffects {
        static let scanlineSpacing: CGFloat = 2.0
        static let scanlineOpacity: CGFloat = 0.1
        static let bloomIntensity: CGFloat = 0.4
        static let blurRadius: CGFloat = 0.5
        static let barrelDistortion: CGFloat = 0.15
        static let vignetteIntensity: CGFloat = 0.2
        static let glowRadius: CGFloat = 3.0
        static let glowOpacity: CGFloat = 0.3
    }

    /// Custom ViewModifier for CRT scanline effect
    private struct CRTScanlineModifier: ViewModifier {
        func body(content: Content) -> some View {
            content.overlay(
                GeometryReader { geometry in
                    Path { path in
                        let lineCount = Int(geometry.size.height / CRTEffects.scanlineSpacing)
                        for i in 0...lineCount {
                            let y = CGFloat(i) * CRTEffects.scanlineSpacing
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }
                    .stroke(Color.black, lineWidth: 0.5)
                    .opacity(CRTEffects.scanlineOpacity)
                }
            )
        }
    }

    /// Custom ViewModifier for CRT barrel distortion effect
    private struct CRTBarrelDistortionModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .distortionEffect(
                    .barrel(radius: CRTEffects.barrelDistortion, intensity: CRTEffects.barrelDistortion),
                    maxSampleOffset: .zero
                )
        }
    }

    var body: some SwiftUI.View {
        if !continueState.isInvalidated {
            Button {
                action()
            } label: {
                ZStack(alignment: .top) {
                    if let screenshot = continueState.image,
                       !screenshot.isInvalidated,
                       let url = screenshot.url,
                       let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: height, alignment: .top)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            // Apply CRT effects
                            .modifier(CRTScanlineModifier())
                            .modifier(CRTBarrelDistortionModifier())
                            .blur(radius: CRTEffects.blurRadius)
                            // Add bloom effect
                            .overlay(
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .blur(radius: CRTEffects.glowRadius)
                                    .opacity(CRTEffects.glowOpacity)
                            )
                            // Add vignette effect
                            .overlay(
                                RadialGradient(
                                    gradient: Gradient(colors: [.clear, .black]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: height
                                )
                                .opacity(CRTEffects.vignetteIntensity)
                            )
                    } else {
                        Image(uiImage: UIImage.missingArtworkImage(gameTitle: continueState.game?.title ?? "Deleted", ratio: 1))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: height, alignment: .top)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            // Apply CRT effects to placeholder image
                            .modifier(CRTScanlineModifier())
                            .modifier(CRTBarrelDistortionModifier())
                            .blur(radius: CRTEffects.blurRadius)
                            // Add vignette effect
                            .overlay(
                                RadialGradient(
                                    gradient: Gradient(colors: [.clear, .black]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: height
                                )
                                .opacity(CRTEffects.vignetteIntensity)
                            )
                            .id(themeManager.currentPalette.name)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(themeManager.currentPalette.gameLibraryText.swiftUIColor, lineWidth: isFocused ? 4 : 0)
                )
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .brightness(isFocused ? 0.1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
            }
            .contextMenu {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Save State", systemImage: "trash")
                }
            }
            .uiKitAlert(
                "Delete Save State",
                message: "Are you sure you want to delete this save state for \(continueState.game?.isInvalidated == true ? "this game" : continueState.game?.title ?? "Deleted")?",
                isPresented: $showDeleteAlert,
                preferredContentSize: CGSize(width: 500, height: 300)
            ) {
                UIAlertAction(title: "Delete", style: .destructive) { _ in
                    do {
                        try RomDatabase.sharedInstance.delete(saveState: continueState)
                    } catch {
                        ELOG("Failed to delete save state: \(error.localizedDescription)")
                    }
                    showDeleteAlert = false
                }
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    showDeleteAlert = false
                }
            }
        }
    }
}

/// Extension to add barrel distortion effect
extension View {
    func distortionEffect(_ effect: DistortionEffect, maxSampleOffset: CGSize) -> some View {
        self.modifier(DistortionEffectModifier(effect: effect))
    }
}

/// Barrel distortion effect implementation
struct DistortionEffect {
    let radius: CGFloat
    let intensity: CGFloat

    static func barrel(radius: CGFloat, intensity: CGFloat) -> DistortionEffect {
        DistortionEffect(radius: radius, intensity: intensity)
    }
}

/// ViewModifier for applying barrel distortion
struct DistortionEffectModifier: ViewModifier {
    let effect: DistortionEffect

    func body(content: Content) -> some View {
        content.drawingGroup() // Use Metal rendering
    }
}
