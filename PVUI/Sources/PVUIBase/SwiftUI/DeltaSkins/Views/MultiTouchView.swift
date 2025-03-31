import SwiftUI
import UIKit

/// A touch phase for the MultiTouchView
public enum MultiTouchPhase {
    case began
    case moved
    case ended
    case cancelled
}

/// A touch with its location
public struct TouchPoint {
    let touch: UITouch
    let location: CGPoint
}

/// A UIKit view that can handle multiple simultaneous touches
public struct MultiTouchView: UIViewRepresentable {
    /// The touch handler closure
    let touchHandler: (MultiTouchPhase, [TouchPoint]) -> Void
    
    public func makeUIView(context: Context) -> TouchDetectingView {
        let view = TouchDetectingView()
        view.touchHandler = touchHandler
        view.isMultipleTouchEnabled = true
        // Use a slightly visible background for debugging
        view.backgroundColor = UIColor(white: 0.5, alpha: 0.1)
        print("MultiTouchView created with frame: \(view.frame)")
        return view
    }
    
    public func updateUIView(_ uiView: TouchDetectingView, context: Context) {
        uiView.touchHandler = touchHandler
    }
    
    /// The UIView that detects touches
    public class TouchDetectingView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            print("TouchDetectingView initialized with frame: \(frame)")
            self.isUserInteractionEnabled = true
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.isUserInteractionEnabled = true
        }
        
        override public func layoutSubviews() {
            super.layoutSubviews()
            print("TouchDetectingView layout updated: \(self.frame)")
        }
        var touchHandler: ((MultiTouchPhase, [TouchPoint]) -> Void)?
        
        override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            handleTouches(.began, touches: touches)
        }
        
        override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            handleTouches(.moved, touches: touches)
        }
        
        override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            handleTouches(.ended, touches: touches)
        }
        
        override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            handleTouches(.cancelled, touches: touches)
        }
        
        private func handleTouches(_ phase: MultiTouchPhase, touches: Set<UITouch>) {
            print("⚡️ MultiTouchView: \(phase) with \(touches.count) touches")
            print("⚡️ View frame: \(self.frame), bounds: \(self.bounds)")
            print("⚡️ isUserInteractionEnabled: \(self.isUserInteractionEnabled)")
            
            let touchPoints = touches.map { touch in
                let location = touch.location(in: self)
                print("⚡️ Touch at \(location) - phase: \(phase)")
                return TouchPoint(touch: touch, location: location)
            }
            
            print("⚡️ MultiTouchView: Handling \(touchPoints.count) touches in phase \(phase)")
            touchHandler?(phase, touchPoints)
        }
    }
}
