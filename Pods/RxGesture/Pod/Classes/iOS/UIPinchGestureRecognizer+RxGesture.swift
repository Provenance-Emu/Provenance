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

public typealias PinchConfiguration = Configuration<UIPinchGestureRecognizer>
public typealias PinchControlEvent = ControlEvent<UIPinchGestureRecognizer>
public typealias PinchObservable = Observable<UIPinchGestureRecognizer>

extension Factory where Gesture == GestureRecognizer {

    /**
     Returns an `AnyFactory` for `UIPinchGestureRecognizer`
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public static func pinch(configuration: PinchConfiguration? = nil) -> AnyFactory {
        return make(configuration: configuration).abstracted()
    }
}

extension Reactive where Base: View {

    /**
     Returns an observable `UIPinchGestureRecognizer` events sequence
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public func pinchGesture(configuration: PinchConfiguration? = nil) -> PinchControlEvent {
        return gesture(make(configuration: configuration))
    }
}

extension ObservableType where Element: UIPinchGestureRecognizer {

    /**
     Maps the observable `GestureRecognizer` events sequence to an observable sequence of scale factors relative to the points of the two touches in screen coordinates alongside the gesture velocity.
     */
    public func asScale() -> Observable<(scale: CGFloat, velocity: CGFloat)> {
        return self.map { gesture in
            return (gesture.scale, gesture.velocity)
        }
    }
}
