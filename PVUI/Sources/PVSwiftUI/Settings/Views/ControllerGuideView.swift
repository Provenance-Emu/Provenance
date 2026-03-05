import SwiftUI
import PVUIBase
import PVThemes

// MARK: - Inline Data Model
// This will be replaced by ControllerGuideInfo from the sibling ticket when merged.

/// Category grouping for controller types
enum ControllerCategory: String, CaseIterable {
    case recommended = "Recommended"
    case legacy = "Legacy"
    case touch = "Touch / On-Screen"
}

/// How a controller connects to the device
enum ControllerConnectionType: String {
    case bluetooth = "Bluetooth"
    case usb = "USB / Wired"
    case lightning = "Lightning"
    case wifi = "Wi-Fi / Network"
    case builtin = "Built-in"
}

/// Platform-specific notes for a controller
struct ControllerPlatformNotes {
    let iOS: String?
    let tvOS: String?
}

/// Represents a single supported controller type with associated guidance
struct ControllerInfo: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let category: ControllerCategory
    let connectionType: ControllerConnectionType
    let features: [String]
    let pairingSteps: [String]
    let systemImageName: String
    let wikiPath: String?
    let platformNotes: ControllerPlatformNotes?
}

// MARK: - Built-in Controller Data

private let supportedControllers: [ControllerInfo] = [
    // MARK: Recommended
    ControllerInfo(
        name: "PlayStation DualSense",
        subtitle: "PS5 Controller",
        category: .recommended,
        connectionType: .bluetooth,
        features: ["Full analog sticks", "Haptic feedback", "Adaptive triggers", "Motion sensor", "Touchpad"],
        pairingSteps: [
            "Press and hold the PS button + Create button until the light bar flashes.",
            "Open Settings > Bluetooth on your device.",
            "Select \"DualSense Wireless Controller\" from the list.",
            "The light bar will stop flashing when connected."
        ],
        systemImageName: "gamecontroller.fill",
        wikiPath: "info/controllers-and-controls/README.md",
        platformNotes: ControllerPlatformNotes(
            iOS: "Works with iOS 14.5+. All buttons fully mapped.",
            tvOS: "Works with tvOS 14.5+. Home button opens Apple TV menu."
        )
    ),
    ControllerInfo(
        name: "PlayStation DualShock 4",
        subtitle: "PS4 Controller",
        category: .recommended,
        connectionType: .bluetooth,
        features: ["Full analog sticks", "Rumble / haptic", "Motion sensor", "Touchpad as button"],
        pairingSteps: [
            "Press and hold the PS button + Share button until the light bar flashes rapidly.",
            "Open Settings > Bluetooth on your device.",
            "Select \"DUALSHOCK 4 Wireless Controller\" from the list.",
            "The light bar will turn solid blue when connected."
        ],
        systemImageName: "gamecontroller.fill",
        wikiPath: "info/controllers-and-controls/README.md",
        platformNotes: ControllerPlatformNotes(
            iOS: "Works with iOS 13+.",
            tvOS: "Works with tvOS 13+."
        )
    ),
    ControllerInfo(
        name: "Xbox Wireless Controller",
        subtitle: "Xbox One / Series X|S",
        category: .recommended,
        connectionType: .bluetooth,
        features: ["Full analog sticks", "Rumble / haptic", "Share button (Series X|S)", "USB-C charging"],
        pairingSteps: [
            "Press and hold the Bluetooth/pair button on the back of the controller.",
            "Open Settings > Bluetooth on your device.",
            "Select \"Xbox Wireless Controller\" from the list.",
            "The Xbox button will stop flashing when connected."
        ],
        systemImageName: "gamecontroller.fill",
        wikiPath: "info/controllers-and-controls/README.md",
        platformNotes: ControllerPlatformNotes(
            iOS: "Requires iOS 13+ (original Xbox One: iOS 14.5+).",
            tvOS: "Requires tvOS 13+."
        )
    ),
    ControllerInfo(
        name: "Nintendo Switch Pro Controller",
        subtitle: "MFi-compatible via Bluetooth",
        category: .recommended,
        connectionType: .bluetooth,
        features: ["Full analog sticks", "Rumble", "NFC", "Motion sensor", "USB-C charging"],
        pairingSteps: [
            "Press and hold the Sync button on the top of the controller.",
            "Open Settings > Bluetooth on your device.",
            "Select \"Pro Controller\" from the list.",
            "The player LEDs will stop flashing when connected."
        ],
        systemImageName: "gamecontroller.fill",
        wikiPath: "info/controllers-and-controls/README.md",
        platformNotes: ControllerPlatformNotes(
            iOS: "Requires iOS 16+. Button labels may differ from MFi layout.",
            tvOS: "Requires tvOS 16+."
        )
    ),
    ControllerInfo(
        name: "MFi Game Controller",
        subtitle: "Made for iPhone/iPad certified",
        category: .recommended,
        connectionType: .bluetooth,
        features: ["Full MFi button set", "Lightning or Bluetooth", "Designed for iOS"],
        pairingSteps: [
            "Put the controller in pairing mode per its manual (usually hold a pairing button).",
            "Open Settings > Bluetooth on your device.",
            "Select the controller from the list.",
            "Some MFi controllers clip onto your device."
        ],
        systemImageName: "gamecontroller",
        wikiPath: "info/controllers-and-controls/README.md",
        platformNotes: ControllerPlatformNotes(
            iOS: "Best native support on iOS — all buttons map perfectly.",
            tvOS: "Works with tvOS. Siri Remote still required for some Apple TV interactions."
        )
    ),
    // MARK: Legacy
    ControllerInfo(
        name: "iCade / 8Bitdo (iCade Mode)",
        subtitle: "Bluetooth HID keyboard-based controllers",
        category: .legacy,
        connectionType: .bluetooth,
        features: ["Works via Bluetooth keyboard HID", "Wide compatibility", "Arcade-style layouts available"],
        pairingSteps: [
            "Pair the controller as a Bluetooth keyboard in Settings > Bluetooth.",
            "In Provenance, go to Settings > Controller > iCade / 8Bitdo.",
            "Select your controller type from the list.",
            "Follow any on-screen prompts to complete setup."
        ],
        systemImageName: "keyboard",
        wikiPath: "info/controllers-and-controls/README.md",
        platformNotes: ControllerPlatformNotes(
            iOS: "Configure in Settings > Controller > iCade / 8Bitdo.",
            tvOS: "Limited support on tvOS — use MFi or modern Bluetooth controllers for best experience."
        )
    ),
    ControllerInfo(
        name: "Keyboard",
        subtitle: "Hardware Bluetooth or USB keyboard",
        category: .legacy,
        connectionType: .bluetooth,
        features: ["WASD / arrow key movement", "Configurable button mapping", "Works on iPad with Smart Keyboard"],
        pairingSteps: [
            "Pair a Bluetooth keyboard via Settings > Bluetooth, or connect a USB keyboard via adapter.",
            "Provenance automatically detects a connected keyboard.",
            "See the Keyboard Controls section in Settings > Controller for the key mapping."
        ],
        systemImageName: "keyboard.fill",
        wikiPath: "info/controllers-and-controls/README.md",
        platformNotes: ControllerPlatformNotes(
            iOS: "Available on iPhone and iPad. See key map in Controller Settings.",
            tvOS: "Keyboard input supported on Apple TV with USB-C adapter."
        )
    ),
    // MARK: Touch
    ControllerInfo(
        name: "On-Screen Controller",
        subtitle: "Touch overlay buttons",
        category: .touch,
        connectionType: .builtin,
        features: ["No hardware required", "Customizable opacity", "Moveable buttons", "Joystick pad for analog systems"],
        pairingSteps: [
            "No pairing needed — the on-screen controller appears automatically.",
            "Adjust opacity in Settings > Controller > On-Screen Controller.",
            "Tap with 3 fingers 3 times to toggle moveable button layout."
        ],
        systemImageName: "hand.point.up.left",
        wikiPath: nil,
        platformNotes: ControllerPlatformNotes(
            iOS: "Available on iPhone and iPad. Appears when no physical controller is connected.",
            tvOS: nil
        )
    )
]

// MARK: - ControllerGuideView

/// A dedicated guide screen explaining supported controllers, pairing steps,
/// controller type differences, and links to the wiki.
public struct ControllerGuideView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var expandedController: UUID?

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    public init() {}

    public var body: some View {
        List {
            controllerTypesSection
            pairingGuideSection
            platformNotesSection
            wikiSection
        }
        #if os(tvOS)
        .listStyle(.plain)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Controller Guide")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.large)
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
        ForEach(ControllerCategory.allCases, id: \.self) { category in
            let controllers = supportedControllers.filter { $0.category == category }
            if !controllers.isEmpty {
                Section {
                    ForEach(controllers) { controller in
                        controllerRow(controller)
                    }
                } header: {
                    sectionHeader(icon: iconForCategory(category), title: category.rawValue)
                }
            }
        }
    }

    @ViewBuilder
    private func controllerRow(_ controller: ControllerInfo) -> some View {
        let isExpanded = expandedController == controller.id
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                expandedController = isExpanded ? nil : controller.id
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack(spacing: 12) {
                    Image(systemName: controller.systemImageName)
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
                        Text(controller.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Connection type badge
                    connectionBadge(controller.connectionType)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isExpanded {
                    Divider()

                    // Features
                    if !controller.features.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Features")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(accentColor)
                                .textCase(.uppercase)
                            ForEach(controller.features, id: \.self) { feature in
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
                    if !controller.pairingSteps.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pairing Steps")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(accentColor)
                                .textCase(.uppercase)
                            ForEach(Array(controller.pairingSteps.enumerated()), id: \.offset) { index, step in
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
                    if let notes = controller.platformNotes {
                        platformNotesView(notes: notes)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        #if os(tvOS)
        .buttonStyle(.card)
        .retroThemedFocus(cornerRadius: 12)
        #else
        .buttonStyle(.plain)
        #endif
    }

    @ViewBuilder
    private func connectionBadge(_ type: ControllerConnectionType) -> some View {
        let (icon, color) = badgeStyle(for: type)
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(type.rawValue)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }

    private func badgeStyle(for type: ControllerConnectionType) -> (String, Color) {
        switch type {
        case .bluetooth: return ("dot.radiowaves.left.and.right", .blue)
        case .usb: return ("cable.connector", .gray)
        case .lightning: return ("bolt.fill", .yellow)
        case .wifi: return ("wifi", .green)
        case .builtin: return ("hand.point.up.left.fill", accentColor)
        }
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
    private func platformNotesView(notes: ControllerPlatformNotes) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Platform Notes")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(accentColor)
                .textCase(.uppercase)
            #if os(tvOS)
            if let tvNote = notes.tvOS {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "appletv")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tvNote)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            #else
            if let iosNote = notes.iOS {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "iphone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(iosNote)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            #endif
        }
    }

    // MARK: Wiki Links

    @ViewBuilder
    private var wikiSection: some View {
        Section {
            NavigationLink(destination: WikiPageView(path: "info/controllers-and-controls/README.md", title: "Controllers & Controls")) {
                Label("Controllers & Controls", systemImage: "books.vertical.fill")
            }
            NavigationLink(destination: WikiPageView(path: "info/controllers-and-controls/bluetooth-controllers.md", title: "Bluetooth Controllers")) {
                Label("Bluetooth Controller Setup", systemImage: "dot.radiowaves.left.and.right")
            }
            NavigationLink(destination: WikiPageView(path: "info/controllers-and-controls/icade-controllers.md", title: "iCade Controllers")) {
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

    private func iconForCategory(_ category: ControllerCategory) -> String {
        switch category {
        case .recommended: return "star.fill"
        case .legacy: return "clock.fill"
        case .touch: return "hand.point.up.left.fill"
        }
    }
}

#if DEBUG
struct ControllerGuideView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ControllerGuideView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
