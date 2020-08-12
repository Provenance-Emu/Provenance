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

public typealias PanConfiguration = Configuration<UIPanGestureRecognizer>
public typealias PanControlEvent = ControlEvent<UIPanGestureRecognizer>
public typealias PanObservable = Observable<UIPanGestureRecognizer>

extension Factory where Gesture == GestureRecognizer {

    /**
     Returns an `AnyFactory` for `UIPanGestureRecognizer`
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public static func pan(configuration: PanConfiguration? = nil) -> AnyFactory {
        return make(configuration: configuration).abstracted()
    }
}

extension Reactive where Base: View {

    /**
     Returns an observable `UIPanGestureRecognizer` events sequence
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public func panGesture(configuration: PanConfiguration? = nil) -> PanControlEvent {
        return gesture(make(configuration: configuration))
    }
}

extension ObservableType where Element: UIPanGestureRecognizer {

    /**
     Maps the observable `GestureRecognizer` events sequence to an observable sequence of translation values of the pan gesture in the coordinate system of the specified `view` alongside the gesture velocity.

     - parameter view: A `TargetView` value on which the gesture took place.
     */
    public func asTranslation(in view: TargetView = .view) -> Observable<(translation: CGPoint, velocity: CGPoint)> {
        return self.map { gesture in
            let view = view.targetView(for: gesture)
            return (
                gesture.translation(in: view),
                gesture.velocity(in: view)
            )
        }
    }
}
