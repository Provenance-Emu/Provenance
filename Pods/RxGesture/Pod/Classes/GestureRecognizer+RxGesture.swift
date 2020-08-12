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

import RxSwift
import RxCocoa

extension ObservableType where Element: GestureRecognizer {

    /**
     Filters the observable `GestureRecognizer` events sequence based on the `GestureRecognizer` state.

     - parameter state: An `GestureRecognizerState` that is used to filter the `GestureRecognizer` events sequence.
     - returns: An observable `GestureRecognizer` events sequence that only contains events emitted while the `GestureRecognizer`'s state match the given `state`.
     */
    public func when(_ states: GestureRecognizerState...) -> Observable<Element> {
        return filter { gesture in
            return states.contains(gesture.state)
        }
    }

    /**
     Filters the observable `GestureRecognizer` events sequence based on the `GestureRecognizer` state.

     - parameter state: An `GestureRecognizerState` that is used to filter the `GestureRecognizer` events sequence.
     - returns: An observable `GestureRecognizer` events sequence that only contains events emitted while the `GestureRecognizer`'s state match the given `state`.
     */
    internal func when(_ states: [GestureRecognizerState]) -> Observable<Element> {
        return filter { gesture in
            return states.contains(gesture.state)
        }
    }

    /**
     Maps the observable `GestureRecognizer` events sequence to an observable sequence of points computed as the location in the given `view` of the gesture.

     - parameter view: A `TargetView` value on which the gesture took place.
     */
    public func asLocation(in view: TargetView = .view) -> Observable<Point> {
        return map { gesture in
            return gesture.location(in: view.targetView(for: gesture))
        }
    }
}
