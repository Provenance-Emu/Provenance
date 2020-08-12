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

public typealias RotationConfiguration = Configuration<UIRotationGestureRecognizer>
public typealias RotationControlEvent = ControlEvent<UIRotationGestureRecognizer>
public typealias RotationObservable = Observable<UIRotationGestureRecognizer>

extension Factory where Gesture == GestureRecognizer {

    /**
     Returns an `AnyFactory` for `UIRotationGestureRecognizer`
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public static func rotation(configuration: RotationConfiguration? = nil) -> AnyFactory {
        return make(configuration: configuration).abstracted()
    }
}

extension Reactive where Base: View {

    /**
     Returns an observable `UIRotationGestureRecognizer` events sequence
     - parameter configuration: A closure that allows to fully configure the gesture recognizer
     */
    public func rotationGesture(configuration: RotationConfiguration? = nil) -> RotationControlEvent {
        return gesture(make(configuration: configuration))
    }
}

extension ObservableType where Element: UIRotationGestureRecognizer {

    /**
     Maps the observable `GestureRecognizer` events sequence to an observable sequence of rotation values of the gesture in radians alongside the gesture velocity.
     */
    public func asRotation() -> Observable<(rotation: CGFloat, velocity: CGFloat)> {
        return self.map { gesture in
            return (gesture.rotation, gesture.velocity)
        }
    }
}
