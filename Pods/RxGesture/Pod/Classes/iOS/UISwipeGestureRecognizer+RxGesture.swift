// Copyright (c) RxSwiftCommunity

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import RxSwift
import RxCocoa

public enum SwipeDirection {
    case right, left, up, down

    #if swift(>=4.2)
    fileprivate typealias SwipeGestureRecognizerDirection = UISwipeGestureRecognizer.Direction
    #else
    fileprivate typealias SwipeGestureRecognizerDirection = UISwipeGestureRecognizerDirection
    #endif

    fileprivate var direction: SwipeGestureRecognizerDirection {
        switch self {
        case .right: return .right
        case .left: return .left
        case .up: return .up
        case .down: return .down
        }
    }
}

private func make(direction: SwipeDirection, configuration: Configuration<UISwipeGestureRecognizer>?) -> Factory<UISwipeGestureRecognizer> {
    return make {
        $0.direction = direction.direction
        configuration?($0, $1)
    }
}

public typealias SwipeConfiguration = Configuration<UISwipeGestureRecognizer>
public typealias SwipeControlEvent = ControlEvent<UISwipeGestureRecognizer>
public typealias SwipeObservable = Observable<UISwipeGestureRecognizer>

extension Factory where Gesture == GestureRecognizer {

    /**
     Returns an `AnyFactory` for `UISwipeGestureRecognizer`
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public static func swipe(direction: SwipeDirection, configuration: SwipeConfiguration? = nil) -> AnyFactory {
        return make(direction: direction, configuration: configuration).abstracted()
    }
}

extension Reactive where Base: View {

    /**
     Returns an observable `UISwipeGestureRecognizer` events sequence
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    private func swipeGesture(direction: SwipeDirection,configuration: SwipeConfiguration? = nil) -> SwipeControlEvent {
        return gesture(make(direction: direction, configuration: configuration))
    }

    /**
     Returns an observable `UISwipeGestureRecognizer` events sequence
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public func swipeGesture(_ directions: Set<SwipeDirection>,configuration: SwipeConfiguration? = nil) -> SwipeControlEvent {
        let source = Observable.merge(directions.map {
            swipeGesture(direction: $0, configuration: configuration).asObservable()
        })
        return ControlEvent(events: source)
    }

    /**
     Returns an observable `UISwipeGestureRecognizer` events sequence
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public func swipeGesture(_ directions: SwipeDirection...,configuration: SwipeConfiguration? = nil) -> SwipeControlEvent {
        return swipeGesture(Set(directions), configuration: configuration)
    }

}
