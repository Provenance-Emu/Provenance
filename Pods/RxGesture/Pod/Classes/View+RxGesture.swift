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

extension Reactive where Base: View {

    /**
     Reactive wrapper for multiple view gesture recognizers.
     It automatically attaches the gesture recognizers to the receiver view.
     The value the `Observable` emits is the gesture recognizer itself.

     rx.anyGesture can't error and is subscribed/observed on main scheduler.
     - parameter factories: a `(Factory + state)` collection you want to use to create the `GestureRecognizers` to add and observe
     - returns: a `ControlEvent<G>` that re-emit the gesture recognizer itself
     */
    public func anyGesture(_ factories: (AnyFactory, when: GestureRecognizerState)...) -> ControlEvent<GestureRecognizer> {
        let observables = factories.map { gesture, state in
            self.gesture(gesture).when(state).asObservable() as Observable<GestureRecognizer>
        }
        let source = Observable.from(observables).merge()
        return ControlEvent(events: source)
    }

    /**
     Reactive wrapper for multiple view gesture recognizers.
     It automatically attaches the gesture recognizers to the receiver view.
     The value the `Observable` emits is the gesture recognizer itself.

     rx.anyGesture can't error and is subscribed/observed on main scheduler.
     - parameter factories: a `Factory` collection you want to use to create the `GestureRecognizers` to add and observe
     - returns: a `ControlEvent<G>` that re-emit the gesture recognizer itself
     */
    public func anyGesture(_ factories: AnyFactory...) -> ControlEvent<GestureRecognizer> {
        let observables = factories.map { factory in
            self.gesture(factory).asObservable() as Observable<GestureRecognizer>
        }
        let source = Observable.from(observables).merge()
        return ControlEvent(events: source)
    }

    /**
     Reactive wrapper for a single view gesture recognizer.
     It automatically attaches the gesture recognizer to the receiver view.
     The value the `Observable` emits is the gesture recognizer itself.

     rx.gesture can't error and is subscribed/observed on main scheduler.
     - parameter factory: a `Factory` you want to use to create the `GestureRecognizer` to add and observe
     - returns: a `ControlEvent<G>` that re-emit the gesture recognizer itself
     */
    public func gesture<G>(_ factory: Factory<G>) -> ControlEvent<G> {
        return self.gesture(factory.gesture)
    }

    /**
     Reactive wrapper for a single view gesture recognizer.
     It automatically attaches the gesture recognizer to the receiver view.
     The value the `Observable` emits is the gesture recognizer itself.

     rx.gesture can't error and is subscribed/observed on main scheduler.
     - parameter gesture: a `GestureRecognizer` you want to add and observe
     - returns: a `ControlEvent<G>` that re-emit the gesture recognizer itself
     */
    public func gesture<G: GestureRecognizer>(_ gesture: G) -> ControlEvent<G> {

        let source = Observable.deferred {
            [weak control = self.base] () -> Observable<G> in
            MainScheduler.ensureExecutingOnScheduler()

            guard let control = control else { return .empty() }

            let genericGesture = gesture as GestureRecognizer

            #if os(iOS)
                control.isUserInteractionEnabled = true
            #endif

            control.addGestureRecognizer(gesture)

            return genericGesture.rx.event
                .map { $0 as! G }
                .startWith(gesture)
                .do(onDispose: { [weak control, weak gesture] () in
                    guard let gesture = gesture else { return }
                    control?.removeGestureRecognizer(gesture)
                })
                .takeUntil(control.rx.deallocated)
        }

        return ControlEvent(events: source)
    }
}
