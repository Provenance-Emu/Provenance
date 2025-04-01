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
        // Create a basic set of buttons for the default skin
        // This will vary based on the system type
        var buttons: [DeltaSkinButton] = []
        
        // The layout depends on orientation
        let isLandscape = traits.orientation == .landscape
        
        // D-pad position and size
        let dpadSize: CGFloat = isLandscape ? 0.15 : 0.2
        let dpadX: CGFloat = isLandscape ? 0.1 : 0.2
        let dpadY: CGFloat = isLandscape ? 0.75 : 0.8
        
        // D-pad buttons
        let dpadUp = DeltaSkinButton(id: "dpad_up", input: .single("up"), frame: CGRect(x: dpadX, y: dpadY - dpadSize, width: dpadSize, height: dpadSize))
        let dpadDown = DeltaSkinButton(id: "dpad_down", input: .single("down"), frame: CGRect(x: dpadX, y: dpadY + dpadSize, width: dpadSize, height: dpadSize))
        let dpadLeft = DeltaSkinButton(id: "dpad_left", input: .single("left"), frame: CGRect(x: dpadX - dpadSize, y: dpadY, width: dpadSize, height: dpadSize))
        let dpadRight = DeltaSkinButton(id: "dpad_right", input: .single("right"), frame: CGRect(x: dpadX + dpadSize, y: dpadY, width: dpadSize, height: dpadSize))
        
        buttons.append(contentsOf: [dpadUp, dpadDown, dpadLeft, dpadRight])
        
        // Action buttons position and size
        let actionSize: CGFloat = isLandscape ? 0.12 : 0.15
        let actionX: CGFloat = isLandscape ? 0.8 : 0.7
        let actionY: CGFloat = isLandscape ? 0.75 : 0.8
        
        // Action buttons (A, B, X, Y)
        let buttonA = DeltaSkinButton(id: "button_a", input: .single("a"), frame: CGRect(x: actionX + actionSize, y: actionY, width: actionSize, height: actionSize))
        let buttonB = DeltaSkinButton(id: "button_b", input: .single("b"), frame: CGRect(x: actionX, y: actionY + actionSize, width: actionSize, height: actionSize))
        
        buttons.append(contentsOf: [buttonA, buttonB])
        
        // Add system-specific buttons based on the system type
        switch systemIdentifier {
        case .NES, .SNES, .GB, .GBC, .GBA, .FDS:
            // Add Start/Select buttons
            let startButton = DeltaSkinButton(id: "button_start", input: .single("start"),
                                             frame: CGRect(x: 0.6, y: 0.9, width: 0.1, height: 0.05))
            let selectButton = DeltaSkinButton(id: "button_select", input: .single("start"),
                                              frame: CGRect(x: 0.4, y: 0.9, width: 0.1, height: 0.05))
            buttons.append(contentsOf: [startButton, selectButton])
            
            // For SNES, add X and Y buttons
            if systemIdentifier == .SNES {
                let buttonX = DeltaSkinButton(id: "button_x", input: .single("x"),
                                             frame: CGRect(x: actionX, y: actionY - actionSize, width: actionSize, height: actionSize))
                let buttonY = DeltaSkinButton(id: "button_y", input: .single("y"),
                                             frame: CGRect(x: actionX - actionSize, y: actionY, width: actionSize, height: actionSize))
                buttons.append(contentsOf: [buttonX, buttonY])
            }
            
        case .Genesis, .SegaCD, .Sega32X, .MasterSystem, .SG1000:
            // Add Start button and C button
            let startButton = DeltaSkinButton(id: "button_start", input: .single("start"),
                                             frame: CGRect(x: 0.5, y: 0.9, width: 0.1, height: 0.05))
            let buttonC = DeltaSkinButton(id: "button_c", input: .single("c"),
                                         frame: CGRect(x: actionX - actionSize, y: actionY + actionSize, width: actionSize, height: actionSize))
            buttons.append(contentsOf: [startButton, buttonC])
            
        default:
            // Add generic Start/Select for other systems
            let startButton = DeltaSkinButton(id: "button_start", input: .single("start"),
                                             frame: CGRect(x: 0.55, y: 0.9, width: 0.1, height: 0.05))
            let selectButton = DeltaSkinButton(id: "button_select", input: .single("select"),
                                              frame: CGRect(x: 0.45, y: 0.9, width: 0.1, height: 0.05))
            buttons.append(contentsOf: [startButton, selectButton])
        }
        
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
        // Create a basic representation for the default skin
        return DeltaSkin.RepresentationInfo(
            assets: .init(resizable: nil, small: nil, medium: nil, large: nil),
            mappingSize: .init(width: 400, height: 300),
            translucent: nil,
            screens: nil,
            items: nil,
            extendedEdges: nil,
            gameScreenFrame: nil
        )
    }
}
