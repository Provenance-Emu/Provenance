import Foundation
import SwiftUI
import PVPrimitives
import UIKit

// RetroGrid view for the background
struct SkinRetroGrid: Shape {
    let lineSpacing: CGFloat
    let lineWidth: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Horizontal lines
        for y in stride(from: 0, to: rect.height, by: lineSpacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        // Vertical lines
        for x in stride(from: 0, to: rect.width, by: lineSpacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        return path
    }
}

// Retrowave sun horizon effect
struct RetrowaveSunrise: View {
    var body: some View {
        ZStack {
            // Sun circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.7),
                            Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(y: 300)
                .blur(radius: 30)
            
            // Horizontal line grid (perspective effect)
            VStack(spacing: 8) {
                ForEach(0..<10) { index in
                    Rectangle()
                        .fill(Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.3 - Double(index) * 0.03))
                        .frame(height: 1)
                }
            }
            .frame(width: 800)
            .offset(y: 300)
        }
    }
}

/// A default implementation of DeltaSkinProtocol that provides a basic skin
public class DefaultDeltaSkin: DeltaSkinProtocol {
    // MARK: - Required Properties
    public let identifier: String
    public let name: String
    public let version: String
    public let author: String
    public let systemIdentifier: SystemIdentifier
    public let supportedOrientations: [DeltaSkinOrientation]
    
    // Required by DeltaSkinProtocol
    public var gameType: DeltaSkinGameType {
        return DeltaSkinGameType(systemIdentifier: systemIdentifier) ?? .gb
    }
    
    public var fileURL: URL {
        // Default skin doesn't have a file URL, but we need to return something
        return URL(fileURLWithPath: "/tmp/default-\(systemIdentifier.rawValue).deltaskin")
    }
    
    public var isDebugEnabled: Bool = false
    
    public var jsonRepresentation: [String: Any] {
        return [
            "identifier": identifier,
            "name": name,
            "version": version,
            "author": author,
            "gameType": systemIdentifier.rawValue,
            "supportedOrientations": supportedOrientations.map { $0.rawValue }
        ]
    }
    
    // MARK: - Additional Properties
    public let url: URL?
    
    public var displayName: String {
        return name
    }
    
    public var displayAuthor: String {
        return author
    }
    
    public var displayVersion: String {
        return version
    }
    
    public var isBuiltIn: Bool {
        return true
    }
    
    public var assetURL: URL? {
        return nil
    }
    
    public var previewImageURL: URL? {
        return nil
    }
    
    public var previewImage: UIImage? {
        return nil
    }
    
    public var screenPosition: CGRect {
        // Position the screen lower on the display for better visibility
        // This addresses the user's request to position the default skin lower
        return CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.6)
    }
    
    public var backgroundColor: Color {
        // Deep blue/purple for retrowave background
        return Color(red: 0.05, green: 0.0, blue: 0.15, opacity: 0.9)
    }
    
    // Add retrowave grid overlay
    public var backgroundOverlay: some View {
        ZStack {
            // Retrowave grid with perspective effect
            GeometryReader { geometry in
                SkinRetroGrid(lineSpacing: 50, lineWidth: 0.5)
                    .stroke(Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.3))
                    .frame(width: geometry.size.width * 2, height: geometry.size.height * 2)
                    .offset(x: -geometry.size.width / 2, y: -geometry.size.height / 2)
            }
            
            // Retrowave sun horizon effect
            RetrowaveSunrise()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Initialization
    /// Initialize a default skin for a system
    /// - Parameter systemId: The system identifier
    public init(systemId: SystemIdentifier) {
        self.identifier = "default-\(systemId.rawValue)"
        self.name = "Default"
        self.version = "1.0"
        self.author = "Provenance"
        self.url = nil
        self.systemIdentifier = systemId
        self.supportedOrientations = [.portrait, .landscape]
    }
    
    // MARK: - Required Methods
    public func supports(_ traits: DeltaSkinTraits) -> Bool {
        // Default skin supports all orientations and devices
        return true
    }
    
    public func image(for traits: DeltaSkinTraits) async throws -> UIImage {
        // Create a retrowave-themed background image
        let imageSize = CGSize(width: 1000, height: 1000)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        
        let backgroundImage = renderer.image { context in
            // Draw a retrowave grid background
            let ctx = context.cgContext
            
            // Fill with a dark background
            UIColor(red: 0.05, green: 0.0, blue: 0.15, alpha: 0.9).setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))
            
            // Draw grid lines with perspective effect
            UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 0.3).setStroke()
            ctx.setLineWidth(1.0)
            
            // Horizontal lines with perspective effect
            let horizonY = imageSize.height * 0.7
            let vanishingPointX = imageSize.width * 0.5
            
            // Draw horizontal lines with perspective
            for i in 0..<20 {
                let y = horizonY + CGFloat(i) * CGFloat(i) * 2.5
                if y < imageSize.height {
                    ctx.move(to: CGPoint(x: 0, y: y))
                    ctx.addLine(to: CGPoint(x: imageSize.width, y: y))
                }
            }
            
            // Draw vertical lines with perspective
            for i in 0..<20 {
                let spacing = imageSize.width / 20
                let x = vanishingPointX + spacing * CGFloat(i)
                if x < imageSize.width {
                    ctx.move(to: CGPoint(x: x, y: horizonY))
                    ctx.addLine(to: CGPoint(x: imageSize.width, y: imageSize.height))
                }
                
                let x2 = vanishingPointX - spacing * CGFloat(i)
                if x2 > 0 {
                    ctx.move(to: CGPoint(x: x2, y: horizonY))
                    ctx.addLine(to: CGPoint(x: 0, y: imageSize.height))
                }
            }
            
            ctx.strokePath()
            
            // Draw a sun/horizon glow
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 0.7).cgColor,
                    UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 0.0).cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            )
            
            let center = CGPoint(x: imageSize.width / 2, y: horizonY)
            ctx.drawRadialGradient(
                gradient!,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: 300,
                options: []
            )
        }
        
        return backgroundImage
    }
    
    public func screens(for traits: DeltaSkinTraits) -> [DeltaSkinScreen]? {
        // Create a default screen that takes up most of the display
        let screenFrame: CGRect
        if traits.orientation == .portrait {
            screenFrame = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.6)
        } else {
            screenFrame = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        }
        
        let screen = DeltaSkinScreen(
            id: "main",
            inputFrame: nil,
            outputFrame: screenFrame,
            placement: .app,
            filters: nil
        )
        return [screen]
    }
    
    public func mappingSize(for traits: DeltaSkinTraits) -> CGSize? {
        // Return a standard mapping size based on device
        switch traits.device {
        case .iphone:
            return CGSize(width: 750, height: 1334)
        case .ipad:
            return CGSize(width: 1024, height: 1366)
        case .tv:
            return CGSize(width: 1920, height: 1080)
        }
    }
    
    public func buttons(for traits: DeltaSkinTraits) -> [DeltaSkinButton]? {
        // Create a retrowave-styled set of buttons with proper gamepad layout
        var buttons: [DeltaSkinButton] = []
        
        // The layout depends on orientation
        let isLandscape = traits.orientation == .landscape
        
        // Common button sizes
        let actionButtonSize: CGFloat = isLandscape ? 0.08 : 0.10
        let shoulderButtonWidth: CGFloat = isLandscape ? 0.12 : 0.15
        let shoulderButtonHeight: CGFloat = isLandscape ? 0.06 : 0.08
        let menuButtonWidth: CGFloat = isLandscape ? 0.12 : 0.15
        let menuButtonHeight: CGFloat = isLandscape ? 0.06 : 0.07
        
        // D-pad position (left side) - positioned for optimal ergonomics
        let dpadCenterX: CGFloat = isLandscape ? 0.15 : 0.20
        let dpadCenterY: CGFloat = isLandscape ? 0.50 : 0.55  // Higher position for better ergonomics
        let dpadRadius: CGFloat = isLandscape ? 0.12 : 0.14    // Larger size for better touch targets
        
        // Create a directional D-pad with a single input mapping
        // Street Fighter style with smaller arrows for diagonals
        // Create a proper D-pad with all directions
        let dpad = DeltaSkinButton(
            id: "dpad",
            input: .directional([
                "up": "up",
                "down": "down",
                "left": "left",
                "right": "right",
                "up_left": "up+left",
                "up_right": "up+right",
                "down_left": "down+left",
                "down_right": "down+right"
            ]),
            frame: CGRect(
                x: dpadCenterX - dpadRadius,
                y: dpadCenterY - dpadRadius,
                width: dpadRadius * 2,
                height: dpadRadius * 2
            )
        )
        buttons.append(dpad)
        
        // Action buttons position (right side) - arranged in proper gamepad layout
        let actionCenterX: CGFloat = isLandscape ? 0.85 : 0.80
        let actionCenterY: CGFloat = isLandscape ? 0.50 : 0.55  // Aligned with D-pad for better ergonomics
        
        // Create action buttons based on system type
        switch systemIdentifier {
        case .SNES:
            // SNES has 4 action buttons in a diamond pattern (proper SNES layout)
            let buttonA = DeltaSkinButton(
                id: "button_a",
                input: .single("a"),
                frame: CGRect(
                    x: actionCenterX + actionButtonSize * 0.6,
                    y: actionCenterY + actionButtonSize * 0.6,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonB = DeltaSkinButton(
                id: "button_b",
                input: .single("b"),
                frame: CGRect(
                    x: actionCenterX - actionButtonSize * 0.6,
                    y: actionCenterY + actionButtonSize * 0.6,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonX = DeltaSkinButton(
                id: "button_x",
                input: .single("x"),
                frame: CGRect(
                    x: actionCenterX + actionButtonSize * 0.6,
                    y: actionCenterY - actionButtonSize * 0.6,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonY = DeltaSkinButton(
                id: "button_y",
                input: .single("y"),
                frame: CGRect(
                    x: actionCenterX - actionButtonSize * 0.6,
                    y: actionCenterY - actionButtonSize * 0.6,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            buttons.append(contentsOf: [buttonA, buttonB, buttonX, buttonY])
            
        case .Genesis, .SegaCD, .Sega32X:
            // Genesis has 3 action buttons in an arc pattern (authentic Genesis layout)
            let buttonA = DeltaSkinButton(
                id: "button_a",
                input: .single("a"),
                frame: CGRect(
                    x: actionCenterX + actionButtonSize * 0.8,
                    y: actionCenterY + actionButtonSize * 0.2,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonB = DeltaSkinButton(
                id: "button_b",
                input: .single("b"),
                frame: CGRect(
                    x: actionCenterX,
                    y: actionCenterY,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonC = DeltaSkinButton(
                id: "button_c",
                input: .single("c"),
                frame: CGRect(
                    x: actionCenterX - actionButtonSize * 0.8,
                    y: actionCenterY + actionButtonSize * 0.2,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            buttons.append(contentsOf: [buttonA, buttonB, buttonC])
            
        default:
            // Most systems have 2 action buttons (A and B) - arranged in proper NES/GB layout
            let buttonA = DeltaSkinButton(
                id: "button_a",
                input: .single("a"),
                frame: CGRect(
                    x: actionCenterX + actionButtonSize * 0.7,
                    y: actionCenterY,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonB = DeltaSkinButton(
                id: "button_b",
                input: .single("b"),
                frame: CGRect(
                    x: actionCenterX - actionButtonSize * 0.7,
                    y: actionCenterY,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            buttons.append(contentsOf: [buttonA, buttonB])
        }
        
        // Add shoulder buttons at the top corners
        if systemIdentifier == .SNES || systemIdentifier == .GBA {
            // Left shoulder button (L)
            let buttonL = DeltaSkinButton(
                id: "button_l",
                input: .single("l"),
                frame: CGRect(
                    x: 0.05,
                    y: 0.05,
                    width: shoulderButtonWidth,
                    height: shoulderButtonHeight
                )
            )
            
            // Right shoulder button (R)
            let buttonR = DeltaSkinButton(
                id: "button_r",
                input: .single("r"),
                frame: CGRect(
                    x: 0.95 - shoulderButtonWidth,
                    y: 0.05,
                    width: shoulderButtonWidth,
                    height: shoulderButtonHeight
                )
            )
            
            buttons.append(contentsOf: [buttonL, buttonR])
        }
        
        // Add Start/Select buttons properly centered at the bottom with proper spacing
        let menuY = isLandscape ? 0.90 : 0.85
        let startX = 0.5 + menuButtonWidth/2 + 0.05 // More spacing between buttons
        let selectX = 0.5 - menuButtonWidth/2 - 0.05
        
        // Start button with retrowave styling
        let startButton = DeltaSkinButton(
            id: "button_start",
            input: .single("start"),
            frame: CGRect(
                x: startX - menuButtonWidth/2,
                y: menuY,
                width: menuButtonWidth,
                height: menuButtonHeight
            )
        )
        
        // Select button with retrowave styling
        let selectButton = DeltaSkinButton(
            id: "button_select",
            input: .single("select"),
            frame: CGRect(
                x: selectX - menuButtonWidth/2,
                y: menuY,
                width: menuButtonWidth,
                height: menuButtonHeight
            )
        )
        
        buttons.append(contentsOf: [startButton, selectButton])
        
        // Add menu and turbo buttons horizontally at the top center
        let menuButtonX = 0.5 - menuButtonWidth - 0.02
        let turboButtonX = 0.5 + 0.02
        let utilityButtonY = isLandscape ? 0.05 : 0.05
        
        // Menu button (previously vertical, now horizontal)
        // Menu button with retrowave styling - positioned at top left
        let menuButton = DeltaSkinButton(
            id: "button_menu",
            input: .single("menu"),
            frame: CGRect(
                x: 0.05,
                y: 0.05,
                width: menuButtonWidth,
                height: menuButtonHeight
            )
        )
        
        // Turbo button (renamed from Fast Forward)
        // Turbo button (renamed from Fast Forward) with retrowave styling - positioned at top right
        let turboButton = DeltaSkinButton(
            id: "button_fast_forward",
            input: .single("fast_forward"),
            frame: CGRect(
                x: 0.95 - menuButtonWidth,
                y: 0.05,
                width: menuButtonWidth,
                height: menuButtonHeight
            )
        )
        
        buttons.append(contentsOf: [menuButton, turboButton])
        
        return buttons
    }
    
    public func screenGroups(for traits: DeltaSkinTraits) -> [DeltaSkinScreenGroup]? {
        // For the default skin, we just have one screen group that contains the main screen
        if let screens = self.screens(for: traits) {
            let group = DeltaSkinScreenGroup(id: "main_group", screens: [.init(id: "main_screen", inputFrame: screenPosition, outputFrame: screenPosition, placement: .app, filters: nil)], extendedEdges: nil, translucent: nil, gameScreenFrame: nil)
            return [group]
        }
        return nil
    }
    
    public func representation(for traits: DeltaSkinTraits) -> DeltaSkin.RepresentationInfo? {
        // Create a basic representation for the default skin with retrowave styling
        return DeltaSkin.RepresentationInfo(
            assets: .init(resizable: nil, small: nil, medium: nil, large: nil),
            mappingSize: .init(width: 400, height: 300),
            translucent: true,  // Make the controller translucent
            screens: nil,
            items: nil,
            extendedEdges: nil,
            gameScreenFrame: nil
        )
    }
}
