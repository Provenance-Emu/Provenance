//
//  ImportTaskRowView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import PVLibrary
import PVRealm
import PVSettings
import PVThemes

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
    case .extracting:
        return "shippingbox.and.arrow.backward.fill"
    }
}

// Individual Import Task Row View
struct ImportTaskRowView: View {
    let item: ImportQueueItem
#if !os(tvOS)
    @State private var isNavigatingToSystemSelection = false
#endif
    @ObservedObject private var themeManager = ThemeManager.shared
    @Default(.unsupportedCores) private var unsupportedCores
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    private var isAppStore: Bool { AppState.shared.isAppStore }

    /// Returns the support level for the resolved or chosen system, if any.
    private var resolvedSupportLevel: CoreSupportLevel? {
        let systemID = item.userChosenSystem ?? item.resolvedSystem
            ?? (item.systems.count == 1 ? item.systems.first : nil)
        guard let systemID else { return nil }
        guard let pvSystem = PVEmulatorConfiguration.system(forIdentifier: systemID) else { return nil }
        let level = pvSystem.coreSupportLevel(isAppStore: isAppStore, unsupportedCores: unsupportedCores)
        return level == .fullySupported ? nil : level
    }

    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var isHovered: Bool = false
#if os(tvOS)
    @FocusState private var isFocusedTV: Bool
    @FocusState private var isFocusedRemove: Bool
#endif

    // Replace delegate with callback
    var onSystemSelected: ((SystemIdentifier, ImportQueueItem) -> Void)?

    /// tvOS: parent sets `systemSelectionItemId` for `navigationDestination` (Siri Remote–friendly).
    var onRequestSystemSelection: (() -> Void)?

    /// tvOS: explicit remove; no swipe-to-delete on list.
    var onRemoveFromQueue: (() -> Void)?

    // Retrowave colors
    var primaryColor: Color {
        switch item.status {
        case .queued: return RetroTheme.retroBlue
        case .processing: return RetroTheme.retroPurple
        case .success: return Color.green
        case .failure: return Color.red
        case .conflict: return RetroTheme.retroPink
        case .partial: return Color.orange
        case .extracting: return RetroTheme.retroGreen
        }
    }

    var secondaryColor: Color {
        switch item.status {
        case .queued, .processing: return RetroTheme.retroPurple
        case .success: return RetroTheme.retroBlue
        case .failure, .conflict: return RetroTheme.retroPink
        case .partial: return RetroTheme.retroBlue
        case .extracting: return RetroTheme.retroDarkBlue
        }
    }

    var background: some View {
        // Solid background fill only — the gradient border is drawn as a separate overlay
        // (see borderOverlay + mainView) so that iOS/tvOS 26 liquid glass applied to the
        // background material does not interact with the custom retro gradient border.
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.7))
    }

    /// Separate retro gradient border — drawn as an overlay so it stays visible above
    /// any iOS/tvOS 26 liquid glass material applied to the background layer.
    var borderOverlay: some View {
#if os(tvOS)
        let lineWidth: CGFloat = isFocusedTV ? 3.0 : 1.5
        let shadowRadius: CGFloat = isFocusedTV ? 8 : 4
#else
        let lineWidth: CGFloat = isHovered ? 2.0 : 1.5
        let shadowRadius: CGFloat = isHovered ? 5 : 3
#endif
        return RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                LinearGradient(
                    gradient: Gradient(colors: [primaryColor, secondaryColor]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: lineWidth
            )
            .shadow(
                color: primaryColor.opacity(glowOpacity),
                radius: shadowRadius,
                x: 0,
                y: 0
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
                    HStack(spacing: 6) {
                        Text("\(chosenSystem.fullName)")
                            .font(.system(size: 14))
                            .foregroundColor(RetroTheme.retroBlue)
                            .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        if let level = resolvedSupportLevel {
                            SystemSupportLevelRow(level: level)
                        }
                    }
                } else if let resolvedSystem = item.resolvedSystem {
                    HStack(spacing: 6) {
                        Text("\(resolvedSystem.fullName)")
                            .font(.system(size: 14))
                            .foregroundColor(RetroTheme.retroBlue)
                            .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        if let level = resolvedSupportLevel {
                            SystemSupportLevelRow(level: level)
                        }
                    }
                } else if !item.systems.isEmpty {
                    if item.systems.count == 1 {
                        HStack(spacing: 6) {
                            Text("\(item.systems.first!.fullName) matched")
                                .font(.system(size: 14))
                                .foregroundColor(RetroTheme.retroBlue)
                                .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                            if let level = resolvedSupportLevel {
                                SystemSupportLevelRow(level: level)
                            }
                        }
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

    private var needsSystemSelection: Bool {
        guard item.userChosenSystem == nil else { return false }
        // Only game/cdRom/unknown file types can have system conflicts
        switch item.fileType {
        case .artwork, .bios, .skin, .patch, .folder:
            return false
        default:
            break
        }
        switch item.status {
        case .conflict:
            return item.systems.count > 1
        case .partial:
            let ext = item.url.pathExtension.lowercased()
            return ext == "cue" || ext == "m3u"
        default:
            return false
        }
    }

    var mainView: some View {
        let base = ZStack {
            // Background with retrowave styling
            background
            // Content
            content
        }
        // The gradient border is applied as an overlay on the ZStack rather than nested
        // inside the background, keeping it above any iOS/tvOS 26 liquid glass treatment.
        .overlay(borderOverlay)
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

#if os(tvOS)
        return tvOSMainRow(base: base)
#else
        return Group {
            if needsSystemSelection {
                NavigationLink(
                    destination: SystemSelectionView(
                        item: item,
                        onSystemSelected: onSystemSelected
                    ),
                    isActive: $isNavigatingToSystemSelection
                ) {
                    base
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                base
                    .onTapGesture { isNavigatingToSystemSelection = false }
            }
        }
        .onTapGesture {
            if needsSystemSelection {
                isNavigatingToSystemSelection = true
            }
        }
#endif
    }

#if os(tvOS)
    /// Row layout for Apple TV: explicit `Button` + optional remove control; parent owns `NavigationStack` destination.
    @ViewBuilder
    private func tvOSMainRow(base: some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if needsSystemSelection {
                    /// `.borderless` tends to activate more reliably than `.plain` with the Siri Remote; `.focusable` keeps `@FocusState` in sync for the retro border.
                    Button(action: { onRequestSystemSelection?() }) {
                        base
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .focusable(true)
                    .focused($isFocusedTV)
                    .scaleEffect(isFocusedTV ? 1.04 : 1.0)
                    .tvOSDisableFocusEffect()
                } else {
                    base
                        .focusable(true)
                        .focused($isFocusedTV)
                        .scaleEffect(isFocusedTV ? 1.04 : 1.0)
                        .tvOSDisableFocusEffect()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if onRemoveFromQueue != nil {
                Button(action: { onRemoveFromQueue?() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                        .frame(width: 56, height: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isFocusedRemove ? 3.0 : 1.5
                                )
                                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: isFocusedRemove ? 8 : 4, x: 0, y: 0)
                        )
                }
                .buttonStyle(.borderless)
                .focusable(true)
                .focused($isFocusedRemove)
                .scaleEffect(isFocusedRemove ? 1.04 : 1.0)
                .tvOSDisableFocusEffect()
            }
        }
    }
#endif

    var body: some View {
        mainView
    }
}

#if os(tvOS)
public struct TVOSDisableFocusEffect: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        if #available(tvOS 17.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}

public extension View {
    func tvOSDisableFocusEffect() -> some View {
        modifier(TVOSDisableFocusEffect())
    }
}
#endif

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
