import Foundation
import PVSettings
import ZIPFoundation

/// Default screen configurations for different console types
enum DeltaSkinDefaults {
    
//    /// Calculate a default screen frame based on game type and available buttons
//    static func defaultScreenFrame(
//        for gameType: DeltaSkinGameType,
//        in mappingSize: CGSize,
//        buttons: [DeltaSkinButton]?,
//        isPreview: Bool
//    ) -> CGRect {
//        // Default to top half of the skin
//        var defaultFrame = CGRect(
//            x: 0,
//            y: 0,
//            width: mappingSize.width,
//            height: mappingSize.height * 0.5
//        )
//        
//        // If we have buttons, try to position above them
//        if let buttons = buttons, !buttons.isEmpty {
//            // Find the topmost button
//            if let topButton = buttons.min(by: { $0.frame.minY < $1.frame.minY }) {
//                // Position screen above the topmost button
//                let buttonTopY = topButton.frame.minY
//                
//                // Use the space above the buttons for the screen
//                defaultFrame = CGRect(
//                    x: 0,
//                    y: 0,
//                    width: mappingSize.width,
//                    height: buttonTopY * 0.95 // Leave a small gap
//                )
//            }
//        }
//        
//        return defaultFrame
//    }
        
    /// Calculate default screen frame when not specified in skin
    static func defaultScreenFrame(
        for gameType: DeltaSkinGameType,
        in mappingSize: CGSize,
        buttons: [DeltaSkinButton]? = nil,
        isPreview: Bool = false
    ) -> CGRect {
        // Get native resolution for the game type
        let nativeSize: CGSize
        switch gameType {
        case .gba:
            nativeSize = CGSize(width: 240, height: 160)
        case .gbc, .gb:
            nativeSize = CGSize(width: 160, height: 144)
        case .genesis, .n64:
            nativeSize = CGSize(width: 320, height: 240)
        case .gamegear:
            nativeSize = CGSize(width: 160, height: 144)  // Game Gear's native resolution
        case .masterSystem:
            nativeSize = CGSize(width: 256, height: 192)  // Master System's native resolution
        case .nes, .snes:
            nativeSize = CGSize(width: 256, height: 224)
        case .nds:
            // Special case for dual screens
            let screenHeight = mappingSize.height * 0.45
            let gap = mappingSize.height * 0.1
            return CGRect(
                x: 0,
                y: isPreview ? 0 : mappingSize.height - screenHeight * 2 - gap,
                width: mappingSize.width,
                height: screenHeight * 2 + gap
            )
        default:
            nativeSize = CGSize(width: 320, height: 240)
        }

        // For preview mode, use simpler centered layout
        if isPreview {
            let maxHeight = mappingSize.height * 0.4 // 40% of height
            let width = min(mappingSize.width, maxHeight * (nativeSize.width / nativeSize.height))
            let height = width / (nativeSize.width / nativeSize.height)
            return CGRect(
                x: (mappingSize.width - width) / 2,
                y: 0,
                width: width,
                height: height
            )
        }

        // Find the available space above controls
        let controlsTopY: CGFloat
        if let buttons = buttons {
            controlsTopY = buttons.reduce(mappingSize.height) { minY, button in
                min(minY, button.frame.minY - (button.extendedEdges?.top ?? 0))
            }
        } else {
            // Adjust default control position based on orientation
            let isLandscape = mappingSize.width > mappingSize.height
            controlsTopY = isLandscape ? mappingSize.height * 0.9 : mappingSize.height * 0.7
        }

        // Calculate screen size based on settings
        let useIntegerScale = Defaults[.integerScaleEnabled]
        let useNativeScale = Defaults[.nativeScaleEnabled]

        // Calculate available space in screen coordinates
        let deviceScale = UIScreen.main.scale
        let isLandscape = mappingSize.width > mappingSize.height

        // Calculate ideal screen dimensions based on orientation and aspect ratio
        let screenSize: CGSize
        if isLandscape {
            // In landscape, we want the height to be the primary constraint
            // Use 80% of the height as our base constraint
            let maxHeight = mappingSize.height * 0.8

            // Calculate width based on native aspect ratio
            let aspectRatio = nativeSize.width / nativeSize.height
            let idealWidth = maxHeight * aspectRatio

            // Ensure width doesn't exceed 50% of screen width (leave room for controls)
            let maxWidth = mappingSize.width * 0.5

            if idealWidth > maxWidth {
                // Width constrained
                screenSize = CGSize(
                    width: maxWidth,
                    height: maxWidth / aspectRatio
                )
            } else {
                // Height constrained
                screenSize = CGSize(
                    width: idealWidth,
                    height: maxHeight
                )
            }
        } else {
            // In portrait, available height is determined by controls
            let maxHeight = controlsTopY - (mappingSize.height * 0.1) // 10% padding
            let maxWidth = mappingSize.width * 0.95 // 5% side padding

            let aspectRatio = nativeSize.width / nativeSize.height
            let idealWidth = maxHeight * aspectRatio

            if idealWidth > maxWidth {
                // Width constrained
                screenSize = CGSize(
                    width: maxWidth,
                    height: maxWidth / aspectRatio
                )
            } else {
                // Height constrained
                screenSize = CGSize(
                    width: idealWidth,
                    height: maxHeight
                )
            }
        }

        // Apply integer/native scaling if enabled
        let finalSize: CGSize
        if useNativeScale {
            let scale = max(2, min(
                screenSize.width / nativeSize.width,
                screenSize.height / nativeSize.height
            ))
            finalSize = CGSize(
                width: nativeSize.width * scale,
                height: nativeSize.height * scale
            )
        } else if useIntegerScale {
            let scale = max(2, floor(min(
                screenSize.width / nativeSize.width,
                screenSize.height / nativeSize.height
            )))
            finalSize = CGSize(
                width: nativeSize.width * scale,
                height: nativeSize.height * scale
            )
        } else {
            finalSize = screenSize
        }

        // Center in available space, adjusting for orientation
        let yPosition: CGFloat
        if isLandscape {
            // In landscape, position screen closer to top
            yPosition = mappingSize.height * 0.05  // 5% from top instead of 10%
        } else {
            // In portrait, position screen higher (25% of the way down from top to controls)
            // This places the screen in the upper portion of the available space
            yPosition = (controlsTopY - finalSize.height) * 0.25
        }

        return CGRect(
            x: (mappingSize.width - finalSize.width) / 2,
            y: yPosition,
            width: finalSize.width,
            height: finalSize.height
        )
    }

    /// Get screen size for device type
    static func screenSize(for device: DeltaSkinDevice) -> CGSize {
        switch device {
        case .iphone:
            return CGSize(width: 390, height: 844)  // iPhone 14 dimensions
        case .ipad:
            return CGSize(width: 820, height: 1180)  // iPad Air dimensions
        case .tv:
            return CGSize(width: 1920, height: 1080)
        }
    }
}

public extension DeltaSkinProtocol {
    /// Load asset data from either directory or archive
    func loadAssetData(_ filename: String) throws -> Data {
        DLOG("Loading asset: \(filename)")

        let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

        if isDirectory {
            // Load from directory
            let assetURL = fileURL.appendingPathComponent(filename)
            guard let data = try? Data(contentsOf: assetURL) else {
                ELOG("Failed to load asset from directory: \(filename)")
                throw DeltaSkinError.missingAsset
            }
            return data
        } else {
            // Load from archive
            guard let archive = Archive(url: fileURL, accessMode: .read),
                  let assetEntry = archive[filename],
                  let data = archive.extractData(assetEntry) else {
                ELOG("Failed to extract asset from archive: \(filename)")
                throw DeltaSkinError.missingAsset
            }
            return data
        }
    }

    /// Read the thumbstick image
    func loadThumbstickImage(named: String) async throws -> UIImage {
        // Load the asset data
        let assetData = try loadAssetData(named)

        // Create image from PDF data since thumbsticks are PDFs
        if named.hasSuffix(".pdf") {
            guard let image = UIImage(pdfData: assetData) else {
                throw DeltaSkinError.invalidPDF
            }
            return image
        } else {
            guard let image = UIImage(data: assetData) else {
                throw DeltaSkinError.invalidPNG
            }
            return image
        }
    }
}
