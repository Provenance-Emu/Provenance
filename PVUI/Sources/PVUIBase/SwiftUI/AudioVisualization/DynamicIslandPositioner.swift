import SwiftUI
import UIKit

/// A utility struct to help position views around the Dynamic Island
struct DynamicIslandPositioner {
    
    /// Get the actual frame of the Dynamic Island/notch in screen coordinates
    static func getDynamicIslandFrame() -> CGRect {
        // Get the window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            // Fallback to hardcoded values if we can't get the window
            return CGRect(x: UIScreen.main.bounds.width/2 - 63, y: 11, width: 126, height: 37)
        }
        
        // Get the safe area insets which tell us about the notch
        let safeAreaInsets = window.safeAreaInsets
        
        // Get device orientation
        let orientation = UIDevice.current.orientation
        
        // Get device model to determine notch dimensions
        let deviceName = UIDevice.current.name
        var notchWidth: CGFloat = 126
        var notchHeight: CGFloat = 37
        
        // Adjust dimensions based on device model
        if deviceName.contains("Max") {
            notchWidth = 126
            notchHeight = 37
        } else if deviceName.contains("iPhone 16 Pro") {
            notchWidth = 126
            notchHeight = 37
        }
        
        // Calculate the frame based on orientation
        switch orientation {
        case .portrait, .unknown, .faceUp, .faceDown:
            // In portrait, the notch is at the top center
            return CGRect(
                x: UIScreen.main.bounds.width/2 - notchWidth/2,
                y: 0,  // Position it at the very top edge
                width: notchWidth,
                height: notchHeight
            )
            
        case .landscapeLeft:
            // In landscape left, the notch is on the right side
            return CGRect(
                x: UIScreen.main.bounds.width - notchHeight,
                y: UIScreen.main.bounds.height/2 - notchWidth/2,
                width: notchHeight,
                height: notchWidth
            )
            
        case .landscapeRight:
            // In landscape right, the notch is on the left side
            return CGRect(
                x: 0,
                y: UIScreen.main.bounds.height/2 - notchWidth/2,
                width: notchHeight,
                height: notchWidth
            )
            
        case .portraitUpsideDown:
            // In portrait upside down, the notch is at the bottom
            return CGRect(
                x: UIScreen.main.bounds.width/2 - notchWidth/2,
                y: UIScreen.main.bounds.height - notchHeight,
                width: notchWidth,
                height: notchHeight
            )
            
        @unknown default:
            // Default to portrait
            return CGRect(
                x: UIScreen.main.bounds.width/2 - notchWidth/2,
                y: 0,
                width: notchWidth,
                height: notchHeight
            )
        }
    }
    
    /// Create a modifier that positions a view at the Dynamic Island
    struct AtDynamicIslandModifier: ViewModifier {
        func body(content: Content) -> some View {
            let frame = getDynamicIslandFrame()
            
            content
                .position(x: frame.midX, y: frame.midY)
                .ignoresSafeArea()
        }
    }
}

extension View {
    /// Position this view at the Dynamic Island
    func positionedAtDynamicIsland() -> some View {
        self.modifier(DynamicIslandPositioner.AtDynamicIslandModifier())
    }
}
