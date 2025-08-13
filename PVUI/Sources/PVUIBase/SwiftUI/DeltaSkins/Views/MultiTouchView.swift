import SwiftUI
import UIKit
import PVLogging

/// A touch phase for the MultiTouchView
public enum MultiTouchPhase {
    case began
    case moved
    case ended
    case cancelled
}

/// A touch with its location
public struct TouchPoint: Identifiable {
    public var id: ObjectIdentifier {
        ObjectIdentifier(touch)
    }
    let touch: UITouch
    let location: CGPoint
}

/// A UIKit view that can handle multiple simultaneous touches
public struct MultiTouchView: UIViewRepresentable {
    /// The touch handler closure
    let touchHandler: (MultiTouchPhase, [TouchPoint]) -> Void
    /// Rects to ignore for hit testing (touches pass through)
    var ignoredRects: [CGRect] = []

    public func makeUIView(context: Context) -> TouchDetectingView {
        let view = TouchDetectingView()
        view.touchHandler = touchHandler
#if !os(tvOS)
        view.isMultipleTouchEnabled = true
#endif
        view.backgroundColor = .clear
        view.ignoredRects = ignoredRects
        DLOG("MultiTouchView created with frame: \(view.frame)")
        return view
    }

    public func updateUIView(_ uiView: TouchDetectingView, context: Context) {
        uiView.touchHandler = touchHandler
        uiView.ignoredRects = ignoredRects
    }

    /// The UIView that detects touches
    public class TouchDetectingView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            DLOG("TouchDetectingView initialized with frame: \(frame)")
            self.isUserInteractionEnabled = true
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.isUserInteractionEnabled = true
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            DLOG("TouchDetectingView layout updated: \(self.frame)")
        }
        var touchHandler: ((MultiTouchPhase, [TouchPoint]) -> Void)?
        var ignoredRects: [CGRect] = []

        /// Allow touches to pass through specific regions so underlying controls (e.g., thumbsticks) can receive gestures
        override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            for rect in ignoredRects {
                if rect.contains(point) { return false }
            }
            return super.point(inside: point, with: event)
        }

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
            DLOG("""
                    ⚡️ MultiTouchView: \(phase) with \(touches.count) touches
                    ⚡️ View frame: \(self.frame), bounds: \(self.bounds), window: \(String(describing: self.window))
                    ⚡️ isUserInteractionEnabled: \(self.isUserInteractionEnabled), alpha: \(self.alpha)
                    ⚡️ superview: \(String(describing: self.superview))
                """)

            let touchPoints = touches.map { touch in
                let location = touch.location(in: self)
                DLOG("⚡️ Touch at \(location) - phase: \(phase), force: \(touch.force)")
                return TouchPoint(touch: touch, location: location)
            }

            DLOG("⚡️ MultiTouchView: Handling \(touchPoints.count) touches in phase \(phase)")
            touchHandler?(phase, touchPoints)
        }
    }
}
