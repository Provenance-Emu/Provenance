//
//  ImportTaskRowView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import PVLibrary
import PVThemes
import Perception

func iconNameForStatus(_ status: ImportQueueItem.ImportStatus) -> String {
    switch status {
        
    case .queued:
        return "play"
    case .processing:
        return "progress.indicator"
    case .success:
        return "checkmark.circle.fill"
    case .failure:
        return "xmark.diamond.fill"
    case .conflict:
        return "exclamationmark.triangle.fill"
    case .partial:
        return "display.trianglebadge.exclamationmark"
    }
}

// Individual Import Task Row View
struct ImportTaskRowView: View {
    let item: ImportQueueItem
    @State private var isNavigatingToSystemSelection = false
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var isHovered: Bool = false
    
    // Replace delegate with callback
    var onSystemSelected: ((SystemIdentifier, ImportQueueItem) -> Void)?
    
    // Retrowave colors
    var primaryColor: Color {
        switch item.status {
        case .queued: return RetroTheme.retroBlue
        case .processing: return RetroTheme.retroPurple
        case .success: return Color.green
        case .failure: return Color.red
        case .conflict: return RetroTheme.retroPink
        case .partial: return Color.orange
        }
    }
    
    var secondaryColor: Color {
        switch item.status {
        case .queued, .processing: return RetroTheme.retroPurple
        case .success: return RetroTheme.retroBlue
        case .failure, .conflict: return RetroTheme.retroPink
        case .partial: return RetroTheme.retroBlue
        }
    }
    
    var background: some View {
        // Background with retrowave styling
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [primaryColor, secondaryColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 2.0 : 1.5
                    )
                    .shadow(color: primaryColor.opacity(glowOpacity), radius: isHovered ? 5 : 3, x: 0, y: 0)
            )
        
    }
    
    var content: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: primaryColor.opacity(glowOpacity * 0.8), radius: 2, x: 0, y: 0)
                    .lineLimit(1)
                
                if item.fileType == .bios {
                    Text("BIOS")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                } else if let chosenSystem = item.userChosenSystem {
                    // Show the selected system when one is chosen
                    Text("\(chosenSystem.fullName)")
                        .font(.system(size: 14))
                        .foregroundColor(RetroTheme.retroBlue)
                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                } else if !item.systems.isEmpty {
                    if item.systems.count == 1 {
                        Text("\(item.systems.first!.fullName) matched")
                            .font(.system(size: 14))
                            .foregroundColor(RetroTheme.retroBlue)
                            .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                    } else {
                        Text("\(item.systems.count) systems")
                            .font(.system(size: 14))
                            .foregroundColor(RetroTheme.retroPurple)
                            .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                    }
                }
                
                if let errorText = item.errorValue {
                    Text("Error: \(errorText)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.red)
                        .shadow(color: Color.red.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        .lineLimit(2)
                }
            }
            .padding(.leading, 10)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                if item.status == .processing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 40, height: 40, alignment: .center)
                        .tint(RetroTheme.retroPurple)
                } else {
                    Image(systemName: iconNameForStatus(item.status))
                        .font(.system(size: 24))
                        .foregroundColor(primaryColor)
                        .shadow(color: primaryColor.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                
                if (item.childQueueItems.count > 0) {
                    Text("+\(item.childQueueItems.count) files")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(
                            Capsule()
                                .stroke(RetroTheme.retroPink, lineWidth: 1)
                                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }
    
    var mainView: some View {
        ZStack {
            // Background with retrowave styling
            background
            // Content
            content
        }
        .frame(height: 90)
        .padding(.vertical, 4)
#if !os(tvOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        #endif
        .onAppear {
            // Start animations
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
        .onTapGesture {
            // Only show system selection if we haven't chosen a system yet
            if item.userChosenSystem == nil {
                switch item.status {
                case .conflict, .failure:
                    isNavigatingToSystemSelection = true
                case .partial:
                    if item.url.pathExtension.lowercased() == "cue" || item.url.pathExtension.lowercased() == "m3u" {
                        isNavigatingToSystemSelection = true
                    }
                default:
                    break
                }
            }
        }
        .background(
            NavigationLink(
                destination: SystemSelectionView(
                    item: item,
                    onSystemSelected: onSystemSelected
                ),
                isActive: $isNavigatingToSystemSelection
            ) {
                EmptyView()
            }
                .hidden()
        )
    }
    
    var body: some View {
        WithPerceptionTracking {
            mainView
        }
    }
}

#if DEBUG
import PVThemes
#Preview {
    List {
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.jpg"), fileType: .artwork))
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.bin"), fileType: .bios))
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.iso"), fileType: .cdRom))
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.jag"), fileType: .game))
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.zip"), fileType: .unknown))
    }
    .onAppear {
        ThemeManager.shared.setCurrentPalette(CGAThemes.green.palette)
    }
}
#endif
