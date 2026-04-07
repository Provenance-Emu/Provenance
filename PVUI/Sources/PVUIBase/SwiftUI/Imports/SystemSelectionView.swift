//
//  SystemSelectionView.swift
//  PVUI
//
//  Created by David Proskin on 11/7/24.
//

import SwiftUI
import PVLibrary
import PVSystems
import PVThemes
import PVRealm
import PVSettings

public struct SystemSelectionView: View {
    @ObservedObject var item: ImportQueueItem
    @Environment(\.dismiss) private var dismiss
    @Default(.unsupportedCores) private var unsupportedCores

    @State private var glowOpacity: Double = 0.7
    @State private var selectedSystem: SystemIdentifier? = nil
    @FocusState private var focusedSystem: SystemIdentifier?

    var onSystemSelected: ((SystemIdentifier, ImportQueueItem) -> Void)?

    public init(item: ImportQueueItem, onSystemSelected: ((SystemIdentifier, ImportQueueItem) -> Void)? = nil) {
        self._item = ObservedObject(wrappedValue: item)
        self.onSystemSelected = onSystemSelected
    }

    private var isAppStore: Bool { AppState.shared.isAppStore }

    private func supportLevel(for systemID: SystemIdentifier) -> CoreSupportLevel {
        guard let pvSystem = PVEmulatorConfiguration.system(forIdentifier: systemID) else {
            return .noCores
        }
        return pvSystem.coreSupportLevel(isAppStore: isAppStore, unsupportedCores: unsupportedCores)
    }

    public var body: some View {
        ZStack {
            // Dark background matching parent sheet
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("SELECT SYSTEM")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .tracking(2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.retroBlue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.retroPink.opacity(0.5), radius: 10)

                    Text(item.url.lastPathComponent)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)

                    Text("\(item.systems.count) possible systems")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 50)
                .padding(.bottom, 30)
                .padding(.horizontal, 60)

                // System list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(item.systems.sorted(), id: \.self) { system in
                            systemRow(system)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, 60)
                }
            }
        }
#if !os(tvOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }

    @ViewBuilder
    private func systemRow(_ system: SystemIdentifier) -> some View {
        let isFocused = focusedSystem == system
        let isSelected = selectedSystem == system
        let level = supportLevel(for: system)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSystem = system
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                item.userChosenSystem = system
                onSystemSelected?(system, item)
                dismiss()
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(system.fullName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    if level != .fullySupported {
                        SystemSupportLevelRow(level: level)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.retroBlue)
                        .shadow(color: Color.retroBlue.opacity(0.6), radius: 4)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isFocused ? 0.06 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isFocused ?
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .focusable()
        .focused($focusedSystem, equals: system)
        .scaleEffect(isFocused ? 1.01 : 1.0)
        .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}

/// SwiftUI color mapping for `CoreSupportLevel`. Defined here so both PVUIBase and PVSwiftUI views share one source.
extension CoreSupportLevel {
    public var badgeColor: Color {
        switch self {
        case .fullySupported: return .green
        case .appStoreRestricted: return .orange
        case .disabled: return .red
        case .noCores: return .gray
        }
    }
}

/// Inline support level indicator used inside system selection rows.
struct SystemSupportLevelRow: View {
    let level: CoreSupportLevel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
                .font(.system(size: 10))
            Text(level.label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(level.badgeColor)
    }
}

#if DEBUG
import PVPrimitives
#Preview {
    let item: ImportQueueItem = {
        let systems: [SystemIdentifier] = [
            .AtariJaguar, .AtariJaguarCD
        ]
        let item = ImportQueueItem(url: .init(fileURLWithPath: "Test.bin"),
                                   fileType: .game)
        item.systems = systems
        return item
    }()

    SystemSelectionView(item: item)
}
#endif
