import UIKit.UIGestureRecognizerSubclass
import RxSwift
import RxCocoa

public class TouchDownGestureRecognizer: UILongPressGestureRecognizer {

    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        minimumPressDuration = 0.0
    }

    /**
     When set to `false`, it allows to bypass the touch ignoring mechanism in order to get absolutely all touch down events.
     Defaults to `true`.
     - note: See [ignore(_ touch: UITouch, for event: UIEvent)](https://developer.apple.com/documentation/uikit/uigesturerecognizer/1620010-ignore)
     */
    public var isTouchIgnoringEnabled: Bool = true

    @nonobjc public var touches: Set<UITouch> = []

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        self.touches.formUnion(touches)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        self.touches.formUnion(touches)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        self.touches.subtract(touches)
    }

    public override  func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        self.touches.subtract(touches)
    }

    public override func reset() {
        super.reset()
        touches = []
    }

    public override func ignore(_ touch: UITouch, for event: UIEvent) {
        guard isTouchIgnoringEnabled else {
            return
        }
        super.ignore(touch, for: event)
    }

}

public typealias TouchDownConfiguration = Configuration<TouchDownGestureRecognizer>
public typealias TouchDownControlEvent = ControlEvent<TouchDownGestureRecognizer>
public typealias TouchDownObservable = Observable<TouchDownGestureRecognizer>

extension Factory where Gesture == GestureRecognizer {

    /**
     Returns an `AnyFactory` for `TouchDownGestureRecognizer`
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public static func touchDown(configuration: TouchDownConfiguration? = nil) -> AnyFactory {
        return make(configuration: configuration).abstracted()
    }
}

extension Reactive where Base: View {

    /**
     Returns an observable `TouchDownGestureRecognizer` events sequence
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public func touchDownGesture(configuration: TouchDownConfiguration? = nil) -> TouchDownControlEvent {

        return gesture(make(configuration: configuration))
    }
}

extension ObservableType where Element: TouchDownGestureRecognizer {

    /**
     Maps the observable `GestureRecognizer` events sequence to an observable sequence of force values.
     */
    public func asTouches() -> Observable<Set<UITouch>> {
        return self.map { $0.touches }
    }
}
