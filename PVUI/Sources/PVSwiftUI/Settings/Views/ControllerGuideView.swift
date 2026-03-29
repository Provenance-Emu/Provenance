import SwiftUI
import PVPrimitives
import PVUIBase
import PVThemes
import PVSettings

// MARK: - Private view-display extensions

/// Maps each ControllerType to the SF Symbol name best representing it in the guide.
private extension ControllerType {
    var sfSymbolName: String {
        switch self {
        case .dualSense, .dualShock4: return "gamecontroller.fill"
        case .xbox: return "gamecontroller.fill"
        case .switchPro: return "gamecontroller"
        case .mfi: return "gamecontroller"
        case .iCade: return "keyboard"
        case .siriRemote: return "appletv.remote.gen2"
        case .keyboard: return "keyboard.fill"
        }
    }

    var connectionBadgeLabel: String {
        switch self {
        case .keyboard: return "BT / USB"
        default: return "Bluetooth"
        }
    }

    var connectionBadgeIcon: String {
        switch self {
        case .iCade, .keyboard: return "keyboard"
        case .siriRemote: return "appletv.remote.gen2"
        default: return "dot.radiowaves.left.and.right"
        }
    }

    var connectionBadgeColor: Color {
        switch self {
        case .iCade, .keyboard: return .retroPink
        case .siriRemote: return .secondary
        default: return .blue
        }
    }

    var iOSNote: String? {
        switch self {
        case .dualSense: return "Works with iOS 14.5+. All buttons fully mapped."
        case .dualShock4: return "Works with iOS 13+."
        case .xbox: return "Requires iOS 13+ (original Xbox One: iOS 14.5+)."
        case .switchPro: return "Requires iOS 16+. Button labels may differ from MFi layout."
        case .mfi: return "Best native support on iOS — all buttons map perfectly."
        case .iCade: return "Configure in Settings > Controllers > iCade / 8Bitdo."
        case .siriRemote: return nil
        case .keyboard: return "Available on iPhone and iPad. See key map in Controller Settings."
        }
    }

    var tvOSNote: String? {
        switch self {
        case .dualSense: return "Works with tvOS 14.5+. Home button opens Apple TV menu."
        case .dualShock4: return "Works with tvOS 13+."
        case .xbox: return "Requires tvOS 13+."
        case .switchPro: return "Requires tvOS 16+."
        case .mfi: return "Works with tvOS. Siri Remote still required for some Apple TV interactions."
        case .iCade: return "Limited support on tvOS — use MFi or modern Bluetooth controllers for best experience."
        case .siriRemote: return "Always available on Apple TV. Limited to 1–2 button games only."
        case .keyboard: return "Keyboard input supported on Apple TV with USB-C adapter."
        }
    }
}

// MARK: - On-Screen Controller (view-only, not a hardware peripheral)

private struct OnScreenControllerEntry {
    let id = "on-screen"
    let name = "On-Screen Controller"
    let subtitle = "Touch overlay buttons"
    let features: [String] = [
        "No hardware required",
        "Customizable opacity",
        "Movable buttons",
        "Joystick pad for analog systems",
    ]
    let pairingSteps: [String] = [
        "No pairing needed — the on-screen controller appears automatically.",
        "Adjust opacity in Settings > Controller > On-Screen Controller.",
        "Tap with 3 fingers 3 times to toggle movable button layout.",
    ]
    let iOSNote: String? = "Available on iPhone and iPad. Appears when no physical controller is connected."
    let tvOSNote: String? = nil
}

private let onScreenEntry = OnScreenControllerEntry()

// MARK: - ControllerGuideView

/// A dedicated guide screen explaining supported controllers, pairing steps,
/// controller type differences, and links to the wiki.
public struct ControllerGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var expandedController: String?

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    public init() {}

    public var body: some View {
        #if os(tvOS)
        ZStack {
            RetroSettingsBackground()

            List {
                controllerTypesSection
                pairingGuideSection
                platformNotesSection
                wikiSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // Indent from left edge to account for the tvOS side-menu bar
            .padding(.leading, 60)
        }
        .navigationTitle("Controller Guide")
        .focusSection()
        .onExitCommand { dismiss() }
        .settingsSubpageTracking()
        #else
        List {
            controllerTypesSection
            pairingGuideSection
            platformNotesSection
            wikiSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Controller Guide")
        .navigationBarTitleDisplayMode(.large)
        .settingsSubpageTracking()
        #endif
    }

    // MARK: Controller Types Overview

    @ViewBuilder
    private var controllerTypesSection: some View {
        Section {
            controllerTypeRow(
                icon: "gamecontroller.fill",
                title: "DualSense / DualShock / Xbox",
                subtitle: "Modern Bluetooth game controllers",
                description: "Fully supported via the Game Controller framework. All buttons, triggers, and analog sticks are recognized automatically. Best overall experience.",
                iconColor: .retroBlue
            )
            controllerTypeRow(
                icon: "gamecontroller",
                title: "MFi (Made for iPhone)",
                subtitle: "Apple-certified controllers",
                description: "Designed specifically for iOS/tvOS. Perfect button mapping and the most reliable connection. Clip-on models available for iPhone.",
                iconColor: .retroPurple
            )
            controllerTypeRow(
                icon: "keyboard",
                title: "iCade / 8Bitdo (iCade mode)",
                subtitle: "Legacy HID keyboard controllers",
                description: "Paired as a Bluetooth keyboard. Requires manual configuration in Settings > Controller > iCade / 8Bitdo. Ideal for arcade-style play.",
                iconColor: .retroPink
            )
            controllerTypeRow(
                icon: "hand.point.up.left",
                title: "On-Screen / Touch",
                subtitle: "No hardware required",
                description: "Built-in touch controller overlaid on the game screen. Appears automatically when no physical controller is detected. Opacity and layout are customizable.",
                iconColor: accentColor
            )
        } header: {
            sectionHeader(icon: "list.bullet.rectangle", title: "Controller Types")
        }
    }

    private func controllerTypeRow(icon: String, title: String, subtitle: String, description: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    #if os(tvOS)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    #endif

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        #if os(tvOS)
                        .foregroundColor(.white)
                        #endif
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Text(description)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    // MARK: Per-Controller Pairing Guide

    @ViewBuilder
    private var pairingGuideSection: some View {
        // Start from the platform-appropriate catalog so iOS-only entries (e.g. iCade)
        // are excluded on tvOS and tvOS-only entries (e.g. Siri Remote) are excluded on iOS.
        #if os(tvOS)
        let platformControllers = ControllerCatalog.tvOSControllers
        #else
        let platformControllers = ControllerCatalog.iOSControllers
        #endif

        // Recommended hardware controllers
        let recommended = platformControllers.filter { $0.isRecommended }
        if !recommended.isEmpty {
            Section {
                ForEach(recommended) { controller in
                    catalogControllerRow(controller)
                }
            } header: {
                sectionHeader(icon: "star.fill", title: "Recommended")
            }
        }

        // Legacy / alternative hardware controllers
        let legacy = platformControllers.filter { !$0.isRecommended }
        if !legacy.isEmpty {
            Section {
                ForEach(legacy) { controller in
                    catalogControllerRow(controller)
                }
            } header: {
                sectionHeader(icon: "clock.fill", title: "Legacy")
            }
        }

        // Touch / software input (on-screen only — not a hardware device)
        #if !os(tvOS)
        Section {
            onScreenControllerRow
        } header: {
            sectionHeader(icon: "hand.point.up.left.fill", title: "Touch / On-Screen")
        }
        #endif
    }

    @ViewBuilder
    private func catalogControllerRow(_ controller: PVPrimitives.ControllerGuideInfo) -> some View {
        let isExpanded = expandedController == controller.id
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                expandedController = isExpanded ? nil : controller.id
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack(spacing: 12) {
                    Image(systemName: controller.controllerType.sfSymbolName)
                        .font(.title2)
                        .foregroundColor(accentColor)
                        .frame(width: 36, height: 36)
                        #if os(tvOS)
                        .background(accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        #endif

                    VStack(alignment: .leading, spacing: 2) {
                        Text(controller.name)
                            .font(.headline)
                            #if os(tvOS)
                            .foregroundColor(.white)
                            #endif
                        Text(controller.controllerType.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    connectionBadge(
                        label: controller.controllerType.connectionBadgeLabel,
                        icon: controller.controllerType.connectionBadgeIcon,
                        color: controller.controllerType.connectionBadgeColor
                    )

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isExpanded {
                    Divider()

                    // Features
                    if !controller.featureNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Features")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(accentColor)
                                .textCase(.uppercase)
                            ForEach(controller.featureNotes, id: \.self) { feature in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text(feature)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }

                    // Pairing steps
                    if !controller.pairingInstructions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pairing Steps")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(accentColor)
                                .textCase(.uppercase)
                            ForEach(Array(controller.pairingInstructions.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(accentColor)
                                        .frame(width: 18, alignment: .leading)
                                    Text(step)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Platform notes
                    platformNotesInlineView(
                        iOSNote: controller.controllerType.iOSNote,
                        tvOSNote: controller.controllerType.tvOSNote
                    )
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        #if os(tvOS)
        .retroFocusButtonStyle(focusScale: 1.03, focusBorderWidth: 2.5, cornerRadius: 12)
        #else
        .buttonStyle(.plain)
        #endif
    }

    @ViewBuilder
    private var onScreenControllerRow: some View {
        let isExpanded = expandedController == onScreenEntry.id
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                expandedController = isExpanded ? nil : onScreenEntry.id
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.point.up.left")
                        .font(.title2)
                        .foregroundColor(accentColor)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(onScreenEntry.name)
                            .font(.headline)
                        Text(onScreenEntry.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    connectionBadge(label: "Built-in", icon: "hand.point.up.left.fill", color: accentColor)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isExpanded {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Features")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(accentColor)
                            .textCase(.uppercase)
                        ForEach(onScreenEntry.features, id: \.self) { feature in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(feature)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Setup")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(accentColor)
                            .textCase(.uppercase)
                        ForEach(Array(onScreenEntry.pairingSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(accentColor)
                                    .frame(width: 18, alignment: .leading)
                                Text(step)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 4)

                    platformNotesInlineView(iOSNote: onScreenEntry.iOSNote, tvOSNote: onScreenEntry.tvOSNote)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func connectionBadge(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }

    // MARK: Platform Notes

    @ViewBuilder
    private var platformNotesSection: some View {
        Section {
            platformNoteRow(
                platform: "iOS / iPadOS",
                icon: "iphone",
                note: "Supports Bluetooth MFi, DualSense, DualShock 4, Xbox, iCade, and on-screen controllers. iOS 13+ required for most modern controllers; iOS 14.5+ for DualSense and original Xbox One."
            )
            platformNoteRow(
                platform: "tvOS (Apple TV)",
                icon: "appletv",
                note: "Supports the same Bluetooth controllers as iOS. The Siri Remote is always available as a basic controller. iCade support is limited. On-screen controllers are not shown on tvOS."
            )
        } header: {
            sectionHeader(icon: "iphone.and.ipad", title: "Platform Notes")
        }
    }

    private func platformNoteRow(platform: String, icon: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(accentColor)
                    .frame(width: 28)
                Text(platform)
                    .font(.headline)
                    #if os(tvOS)
                    .foregroundColor(.white)
                    #endif
            }
            Text(note)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func platformNotesInlineView(iOSNote: String?, tvOSNote: String?) -> some View {
        let hasNote: Bool = {
            #if os(tvOS)
            return tvOSNote != nil
            #else
            return iOSNote != nil
            #endif
        }()
        if hasNote {
            VStack(alignment: .leading, spacing: 4) {
                Text("Platform Notes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                    .textCase(.uppercase)
                #if os(tvOS)
                if let note = tvOSNote {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "appletv")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(note)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                #else
                if let note = iOSNote {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(note)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                #endif
            }
        }
    }

    // MARK: Wiki Links

    @ViewBuilder
    private var wikiSection: some View {
        Section {
            NavigationLink(destination: WikiPageView(path: "info/controllers-and-controls/README.md", title: "Controllers & Controls").settingsSubpageTracking()) {
                Label("Controllers & Controls", systemImage: "books.vertical.fill")
            }
            NavigationLink(destination: WikiPageView(path: "info/controllers-and-controls/bluetooth-controllers.md", title: "Bluetooth Controllers").settingsSubpageTracking()) {
                Label("Bluetooth Controller Setup", systemImage: "dot.radiowaves.left.and.right")
            }
            NavigationLink(destination: WikiPageView(path: "info/controllers-and-controls/icade-controllers.md", title: "iCade Controllers").settingsSubpageTracking()) {
                Label("iCade / 8Bitdo Setup", systemImage: "keyboard")
            }
        } header: {
            sectionHeader(icon: "questionmark.circle", title: "Help & Wiki")
        } footer: {
            Text("Wiki pages are fetched from the Provenance project wiki and may require an internet connection.")
                .font(.footnote)
        }
    }

    // MARK: Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.headline)
        #if os(tvOS)
        .foregroundColor(.retroPink)
        #endif
    }
}

#if DEBUG
struct ControllerGuideView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ControllerGuideView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
