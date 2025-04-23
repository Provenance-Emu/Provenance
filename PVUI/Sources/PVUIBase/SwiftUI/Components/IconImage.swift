//
//  IconImage.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/3/25.
//

import SwiftUI

/// Custom IconImage view adapted for our app icons
public struct IconImage: View {
    public var iconName: String
    public var size: CGFloat
    @State private var defaultIcon: UIImage?

    private var previewImageName: String {
        "\(iconName)-Preview"
    }
    
    public init(iconName: String, size: CGFloat, defaultIcon: UIImage? = nil) {
        self.iconName = iconName
        self.size = size
        self._defaultIcon = State(initialValue: defaultIcon)
        
        // Load default icon immediately if we're showing the AppIcon
        if iconName == "AppIcon" && defaultIcon == nil {
            loadDefaultIcon()
        }
    }

    public var body: some View {
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
            if iconName == "AppIcon" && defaultIcon == nil {
                loadDefaultIcon()
            }
        }
    }
    
    /// Load the default app icon from the Info.plist
    private func loadDefaultIcon() {
        guard
            let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let iconFileName = iconFiles.last,
            let icon = UIImage(named: iconFileName)
        else { return }
        
        DispatchQueue.main.async {
            self.defaultIcon = icon
        }
    }
}
