import Foundation
import SwiftUI
import PVPrimitives
import UIKit

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
        // Remove the gray background as requested by the user
        return Color.clear
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
        // Create a transparent image as the default skin background
        let size = traits.device == .ipad ? CGSize(width: 1024, height: 1366) : CGSize(width: 750, height: 1334)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Draw a very subtle gradient background
            let colors = [
                UIColor.black.withAlphaComponent(0.1).cgColor,
                UIColor.clear.cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray,
                                     locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient,
                                              start: CGPoint(x: 0, y: 0),
                                              end: CGPoint(x: 0, y: size.height),
                                              options: [])
        }
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
        
        // D-pad position (left side)
        let dpadCenterX: CGFloat = isLandscape ? 0.15 : 0.20
        let dpadCenterY: CGFloat = isLandscape ? 0.60 : 0.70
        let dpadRadius: CGFloat = isLandscape ? 0.10 : 0.12
        
        // Create a directional D-pad with a single input mapping
        let dpad = DeltaSkinButton(
            id: "dpad",
            input: .directional([
                "up": "up",
                "down": "down",
                "left": "left",
                "right": "right"
            ]),
            frame: CGRect(
                x: dpadCenterX - dpadRadius,
                y: dpadCenterY - dpadRadius,
                width: dpadRadius * 2,
                height: dpadRadius * 2
            )
        )
        buttons.append(dpad)
        
        // Action buttons position (right side)
        let actionCenterX: CGFloat = isLandscape ? 0.85 : 0.80
        let actionCenterY: CGFloat = isLandscape ? 0.60 : 0.70
        
        // Create action buttons based on system type
        switch systemIdentifier {
        case .SNES:
            // SNES has 4 action buttons in a diamond pattern
            let buttonA = DeltaSkinButton(
                id: "button_a",
                input: .single("a"),
                frame: CGRect(
                    x: actionCenterX + actionButtonSize/2,
                    y: actionCenterY,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonB = DeltaSkinButton(
                id: "button_b",
                input: .single("b"),
                frame: CGRect(
                    x: actionCenterX,
                    y: actionCenterY + actionButtonSize/2,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonX = DeltaSkinButton(
                id: "button_x",
                input: .single("x"),
                frame: CGRect(
                    x: actionCenterX,
                    y: actionCenterY - actionButtonSize/2,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonY = DeltaSkinButton(
                id: "button_y",
                input: .single("y"),
                frame: CGRect(
                    x: actionCenterX - actionButtonSize/2,
                    y: actionCenterY,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            buttons.append(contentsOf: [buttonA, buttonB, buttonX, buttonY])
            
        case .Genesis, .SegaCD, .Sega32X:
            // Genesis has 3 action buttons in a row
            let buttonA = DeltaSkinButton(
                id: "button_a",
                input: .single("a"),
                frame: CGRect(
                    x: actionCenterX - actionButtonSize,
                    y: actionCenterY,
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
                    x: actionCenterX + actionButtonSize,
                    y: actionCenterY,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            buttons.append(contentsOf: [buttonA, buttonB, buttonC])
            
        default:
            // Most systems have 2 action buttons (A and B)
            let buttonA = DeltaSkinButton(
                id: "button_a",
                input: .single("a"),
                frame: CGRect(
                    x: actionCenterX + actionButtonSize/2,
                    y: actionCenterY,
                    width: actionButtonSize,
                    height: actionButtonSize
                )
            )
            
            let buttonB = DeltaSkinButton(
                id: "button_b",
                input: .single("b"),
                frame: CGRect(
                    x: actionCenterX,
                    y: actionCenterY + actionButtonSize/2,
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
        
        // Add Start/Select buttons centered at the bottom
        let startX = 0.5 + menuButtonWidth/2 + 0.02
        let selectX = 0.5 - menuButtonWidth/2 - 0.02
        let menuY = isLandscape ? 0.90 : 0.88
        
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
