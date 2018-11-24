import UIKit.UIView
#if !PMKCocoaPods
import PromiseKit
#endif

/**
 To import the `UIView` category:

    use_frameworks!
    pod "PromiseKit/UIKit"

 Or `UIKit` is one of the categories imported by the umbrella pod:

    use_frameworks!
    pod "PromiseKit"

 And then in your sources:

    import PromiseKit
*/
public extension UIView {
#if swift(>=4.2)
/**
     Animate changes to one or more views using the specified duration, delay,
     options, and completion handler.

     - Parameter duration: The total duration of the animations, measured in
     seconds. If you specify a negative value or 0, the changes are made
     without animating them.

     - Parameter delay: The amount of time (measured in seconds) to wait before
     beginning the animations. Specify a value of 0 to begin the animations
     immediately.

     - Parameter options: A mask of options indicating how you want to perform the
     animations. For a list of valid constants, see UIViewAnimationOptions.

     - Parameter animations: A block object containing the changes to commit to the
     views.

     - Returns: A promise that fulfills with a boolean NSNumber indicating
     whether or not the animations actually finished.
    */
    @discardableResult
    static func animate(_: PMKNamespacer, duration: TimeInterval, delay: TimeInterval = 0, options: UIView.AnimationOptions = [], animations: @escaping () -> Void) -> Guarantee<Bool> {
        return Guarantee { animate(withDuration: duration, delay: delay, options: options, animations: animations, completion: $0) }
    }

    @discardableResult
    static func animate(_: PMKNamespacer, duration: TimeInterval, delay: TimeInterval, usingSpringWithDamping damping: CGFloat, initialSpringVelocity: CGFloat, options: UIView.AnimationOptions = [], animations: @escaping () -> Void) -> Guarantee<Bool> {
        return Guarantee { animate(withDuration: duration, delay: delay, usingSpringWithDamping: damping, initialSpringVelocity: initialSpringVelocity, options: options, animations: animations, completion: $0) }
    }

    @discardableResult
    static func transition(_: PMKNamespacer, with view: UIView, duration: TimeInterval, options: UIView.AnimationOptions = [], animations: (() -> Void)?) -> Guarantee<Bool> {
        return Guarantee { transition(with: view, duration: duration, options: options, animations: animations, completion: $0) }
    }

    @discardableResult
    static func transition(_: PMKNamespacer, from: UIView, to: UIView, duration: TimeInterval, options: UIView.AnimationOptions = []) -> Guarantee<Bool> {
        return Guarantee { transition(from: from, to: to, duration: duration, options: options, completion: $0) }
    }

    @discardableResult
    static func perform(_: PMKNamespacer, animation: UIView.SystemAnimation, on views: [UIView], options: UIView.AnimationOptions = [], animations: (() -> Void)?) -> Guarantee<Bool> {
        return Guarantee { perform(animation, on: views, options: options, animations: animations, completion: $0) }
    }
#else
    /**
     Animate changes to one or more views using the specified duration, delay,
     options, and completion handler.
     
     - Parameter duration: The total duration of the animations, measured in
     seconds. If you specify a negative value or 0, the changes are made
     without animating them.

     - Parameter delay: The amount of time (measured in seconds) to wait before
     beginning the animations. Specify a value of 0 to begin the animations
     immediately.
     
     - Parameter options: A mask of options indicating how you want to perform the
     animations. For a list of valid constants, see UIViewAnimationOptions.

     - Parameter animations: A block object containing the changes to commit to the
     views.

     - Returns: A promise that fulfills with a boolean NSNumber indicating
     whether or not the animations actually finished.
    */
    @discardableResult
    static func animate(_: PMKNamespacer, duration: TimeInterval, delay: TimeInterval = 0, options: UIViewAnimationOptions = [], animations: @escaping () -> Void) -> Guarantee<Bool> {
        return Guarantee { animate(withDuration: duration, delay: delay, options: options, animations: animations, completion: $0) }
    }

    @discardableResult
    static func animate(_: PMKNamespacer, duration: TimeInterval, delay: TimeInterval, usingSpringWithDamping damping: CGFloat, initialSpringVelocity: CGFloat, options: UIViewAnimationOptions = [], animations: @escaping () -> Void) -> Guarantee<Bool> {
        return Guarantee { animate(withDuration: duration, delay: delay, usingSpringWithDamping: damping, initialSpringVelocity: initialSpringVelocity, options: options, animations: animations, completion: $0) }
    }
    
    @discardableResult
    static func transition(_: PMKNamespacer, with view: UIView, duration: TimeInterval, options: UIViewAnimationOptions = [], animations: (() -> Void)?) -> Guarantee<Bool> {
        return Guarantee { transition(with: view, duration: duration, options: options, animations: animations, completion: $0) }
    }
               
    @discardableResult
    static func transition(_: PMKNamespacer, from: UIView, to: UIView, duration: TimeInterval, options: UIViewAnimationOptions = []) -> Guarantee<Bool> {
        return Guarantee { transition(from: from, to: to, duration: duration, options: options, completion: $0) }
    }

    @discardableResult
    static func perform(_: PMKNamespacer, animation: UISystemAnimation, on views: [UIView], options: UIViewAnimationOptions = [], animations: (() -> Void)?) -> Guarantee<Bool> {
        return Guarantee { perform(animation, on: views, options: options, animations: animations, completion: $0) }
    }
#endif
}
