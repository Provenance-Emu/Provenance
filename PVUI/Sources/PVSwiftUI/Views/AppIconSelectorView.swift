import SwiftUI
import struct PVUIBase.NeumorphismView

enum AppIconOption: String, CaseIterable {
    case `default` = "AppIcon"
    case bit1 = "AppIcon-8bit1"
    case bit2 = "AppIcon-8bit2"
    case bit3 = "AppIcon-8bit3"
    case bit4 = "AppIcon-8bit4"
    case bit5 = "AppIcon-8bit5"
    case blueNegative = "AppIcon-Blue-Negative"
    case blue = "AppIcon-Blue"
    case cyan = "AppIcon-Cyan"
    case gem = "AppIcon-Gem"
    case gold = "AppIcon-Gold"
    case paint1 = "AppIcon-Paint1"
    case paint2 = "AppIcon-Paint2"
    case purple = "AppIcon-Purple"
    case seafoam = "AppIcon-Seafoam"
    case yellow = "AppIcon-Yellow"

    /// User-friendly display name
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .bit1: return "8-Bit Style 1"
        case .bit2: return "8-Bit Style 2"
        case .bit3: return "8-Bit Style 3"
        case .bit4: return "8-Bit Style 4"
        case .bit5: return "8-Bit Style 5"
        case .blueNegative: return "Blue Negative"
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .gem: return "Gem"
        case .gold: return "Gold"
        case .paint1: return "Paint Style 1"
        case .paint2: return "Paint Style 2"
        case .purple: return "Purple"
        case .seafoam: return "Seafoam"
        case .yellow: return "Yellow"
        }
    }
}

/// Custom IconImage view adapted for our app icons
struct IconImage: View {
    var iconName: String
    var size: CGFloat
    @State private var defaultIcon: UIImage?

    private var previewImageName: String {
        "\(iconName)-Preview"
    }

    var body: some View {
        Label {
            Text(iconName)
        } icon: {
            Group {
                if iconName == "AppIcon", let defaultIcon {
                    /// Use the default icon from info.plist
                    Image(uiImage: defaultIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                        .cornerRadius(size * 0.2)
                        .shadow(radius: 4)
                } else if let uiImage = UIImage(named: previewImageName, in: .main, with: nil) {
                    /// Use preview images for alternate icons
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                        .cornerRadius(size * 0.2)
                        .shadow(radius: 4)
                } else {
                    /// Fallback placeholder
                    Color.gray.opacity(0.1)
                        .frame(width: size, height: size)
                        .cornerRadius(size * 0.2)
                        .overlay(
                            Image(systemName: "app.fill")
                                .foregroundColor(.gray)
                        )
                }
            }
            .contextMenu {
                Button {
                    // No action needed, just for preview
                } label: {
                    if let previewImage = (iconName == "AppIcon" ? defaultIcon : UIImage(named: previewImageName)) {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 256, height: 256)
                    }
                }
            } preview: {
                if let previewImage = (iconName == "AppIcon" ? defaultIcon : UIImage(named: previewImageName)) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 256, height: 256)
                        .cornerRadius(20)
                }
            }
        }
        .labelStyle(.iconOnly)
        .task {
            if iconName == "AppIcon" {
                /// Load primary icon from info.plist
                guard
                    let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
                    let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
                    let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
                    let iconFileName = iconFiles.last,
                    let icon = UIImage(named: iconFileName)
                else { return }
                self.defaultIcon = icon
            }
        }
    }
}

struct AppIconSelectorView: View {
    @StateObject private var iconManager = IconManager.shared

    /// Smaller grid items for better layout
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 120), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current icon preview
                VStack(spacing: 8) {
                    Text("Current App Icon")
                        .font(.title2)

                    /// Current icon with neumorphic style
                    NeumorphismView {
                        IconImage(
                            iconName: iconManager.currentIconName ?? "AppIcon",
                            size: 180
                        )
                        .padding(8)
                    }
                }
                .padding(.top)

                // Icon grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AppIconOption.allCases, id: \.self) { option in
                        VStack(spacing: 8) {
                            /// Grid items with neumorphic style
                            NeumorphismView {
                                IconImage(
                                    iconName: option.rawValue,
                                    size: 64
                                )
                                .padding(8)
                            }
                            .onTapGesture {
                                changeAppIcon(to: option)
                            }

                            Text(option.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 84, height: 84)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            // Debug: Print available images
            AppIconOption.allCases.forEach { option in
                if UIImage(named: option.rawValue, in: .main, with: nil) != nil {
                    print("✅ Found icon: \(option.rawValue)")
                } else {
                    print("❌ Missing icon: \(option.rawValue)")
                }
            }
        }
    }

    private func changeAppIcon(to option: AppIconOption) {
        let iconName = option == .default ? nil : option.rawValue

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Error changing app icon: \(error.localizedDescription)")
            } else {
                iconManager.currentIconName = iconName
            }
        }
    }
}

#Preview {
    AppIconSelectorView()
}
