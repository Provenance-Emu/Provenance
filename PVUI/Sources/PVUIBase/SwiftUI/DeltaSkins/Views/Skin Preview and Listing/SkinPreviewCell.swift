//
//  SkinPreviewCell.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/30/25.
//

import SwiftUI

/// Preview cell for a skin with rubber-like design
struct SkinPreviewCell: View {
    let skin: any DeltaSkinProtocol
    let manager: DeltaSkinManager
    var orientation: DeltaSkinOrientation = .portrait
    
    @State private var showingDeleteAlert = false
    @State private var deleteError: Error?
    @State private var showingErrorAlert = false
    #if !os(tvOS)
    @State private var showingShareSheet = false
    #endif
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    // Rubber-like colors
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.85)
    }

    private var innerShadowColor: Color {
        colorScheme == .dark ? .black : Color(white: 0.7)
    }

    private var embossHighlightColor: Color {
        colorScheme == .dark ? Color(white: 0.25) : Color.white
    }

    private var previewTraits: DeltaSkinTraits {
        // Try current device first with specified orientation
        let device: DeltaSkinDevice = horizontalSizeClass == .regular ? .ipad : .iphone
        let traits = DeltaSkinTraits(device: device, displayType: .standard, orientation: orientation)

        // Return first supported configuration
        if skin.supports(traits) {
            return traits
        }
        
        // Try with edge to edge display type
        let edgeToEdgeTraits = DeltaSkinTraits(device: device, displayType: .edgeToEdge, orientation: orientation)
        if skin.supports(edgeToEdgeTraits) {
            return edgeToEdgeTraits
        }

        // Try alternate device
        let altDevice: DeltaSkinDevice = device == .ipad ? .iphone : .ipad
        let altTraits = DeltaSkinTraits(device: altDevice, displayType: .standard, orientation: orientation)

        if skin.supports(altTraits) {
            return altTraits
        }
        
        // Try alternate device with edge to edge
        let altEdgeToEdgeTraits = DeltaSkinTraits(device: altDevice, displayType: .edgeToEdge, orientation: orientation)
        if skin.supports(altEdgeToEdgeTraits) {
            return altEdgeToEdgeTraits
        }
        
        // If the requested orientation isn't supported, try the opposite orientation
        let oppositeOrientation: DeltaSkinOrientation = orientation == .portrait ? .landscape : .portrait
        let oppositeTraits = DeltaSkinTraits(device: device, displayType: .standard, orientation: oppositeOrientation)
        
        if skin.supports(oppositeTraits) {
            return oppositeTraits
        }

        // Fallback to edge to edge with default orientation
        return DeltaSkinTraits(device: device, displayType: .edgeToEdge, orientation: .portrait)
    }

    var body: some View {
        ZStack {
            // Preview content with disabled interaction
            content
                .allowsHitTesting(false)  // Disable interaction on the preview content

            // Transparent overlay to capture context menu
            Color.clear
                .contentShape(Rectangle())  // Make entire area tappable
        }
        .contextMenu {
            #if !os(tvOS)
            Button {
                showingShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            #endif

            if manager.isDeletable(skin) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .retroAlert("Delete Skin?",
                    message: "Are you sure you want to delete '\(skin.name)'? This cannot be undone.",
                    isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await manager.deleteSkin(skin.identifier)
                    } catch {
                        deleteError = error
                        showingErrorAlert = true
                    }
                }
            }
        }
        .retroAlert("Delete Error",
                    message: deleteError?.localizedDescription ?? "",
                    isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        }
        #if !os(tvOS)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [skin.fileURL])
        }
        #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview
            PreviewContainer {
                DeltaSkinView(skin: skin, traits: previewTraits, inputHandler: .init(emulatorCore: nil))
                    .allowsHitTesting(false)
                    .aspectRatio(orientation == .portrait ? 0.5 : 2.0, contentMode: .fit)
            }
            .overlay {
                // Rubber-like gradient overlay
                LinearGradient(
                    colors: [
                        .black.opacity(0.4),
                        .clear,
                        .black.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(skin.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Label(skin.gameType.systemIdentifier?.fullName ?? skin.gameType.rawValue,
                          systemImage: "gamecontroller")
                        .lineLimit(1)

                    Spacer()

                    DeviceIndicators(skin: skin)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            ZStack {
                // Base rubber texture
                backgroundColor

                // Noise texture overlay for rubber effect
                Color.black
                    .opacity(0.05)
                    .blendMode(.overlay)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            // Embossed edge effect
            RoundedRectangle(cornerRadius: 16)
                .stroke(innerShadowColor, lineWidth: 2)
                .blur(radius: 2)
                .mask(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(lineWidth: 2)
                )
                .blendMode(.overlay)
        }
        .overlay {
            // Inner shadow for depth
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.5)
                .stroke(embossHighlightColor, lineWidth: 1)
                .blur(radius: 1)
                .opacity(0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
        .padding(2)
    }
}
