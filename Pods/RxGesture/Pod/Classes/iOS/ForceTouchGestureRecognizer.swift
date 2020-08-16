import UIKit.UIGestureRecognizerSubclass
import RxSwift
import RxCocoa

@available(iOS 9.0, *)
public class ForceTouchGestureRecognizer: UIGestureRecognizer {

    public var numberOfTouchesRequired: Int = 1
    public private(set) var force: CGFloat = 0
    public private(set) var maximumPossibleForce: CGFloat = 0
    public var fractionCompleted: CGFloat {
        guard maximumPossibleForce > 0 else {
            return 0
        }
        return force / maximumPossibleForce
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        state = .began
        setForce(for: touches)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        state = .changed
        setForce(for: touches)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        state = .ended
        setForce(for: touches)
    }

    private func setForce(for touches: Set<UITouch>) {
        guard touches.count == numberOfTouchesRequired, let touch = touches.first else {
            state = .failed
            return
        }
        force = Array(touches)[1...]
            .lazy
            .map { $0.force}
            .reduce(touch.force, +) / CGFloat(touches.count)

        maximumPossibleForce = Array(touches)[1...]
            .lazy
            .map { $0.maximumPossibleForce}
            .reduce(touch.maximumPossibleForce, +) / CGFloat(touches.count)
    }
}

@available(iOS 9.0, *)
public typealias ForceTouchConfiguration = Configuration<ForceTouchGestureRecognizer>
@available(iOS 9.0, *)
public typealias ForceTouchControlEvent = ControlEvent<ForceTouchGestureRecognizer>
@available(iOS 9.0, *)
public typealias ForceTouchObservable = Observable<ForceTouchGestureRecognizer>

@available(iOS 9.0, *)
extension Factory where Gesture == GestureRecognizer {

    /**
     Returns an `AnyFactory` for `ForceTouchGestureRecognizer`
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public static func forceTouch(configuration: ForceTouchConfiguration? = nil) -> AnyFactory {
        return make(configuration: configuration).abstracted()
    }
}

@available(iOS 9.0, *)
extension Reactive where Base: View {

    /**
     Returns an observable `ForceTouchGestureRecognizer` events sequence
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public func forceTouchGesture(configuration: ForceTouchConfiguration? = nil) -> ForceTouchControlEvent {
        return gesture(make(configuration: configuration))
    }
}

@available(iOS 9.0, *)
extension ObservableType where Element: ForceTouchGestureRecognizer {

    /**
     Maps the observable `GestureRecognizer` events sequence to an observable sequence of force values.
     */
    public func asForce() -> Observable<CGFloat> {
        return self.map { $0.force }
    }
}
