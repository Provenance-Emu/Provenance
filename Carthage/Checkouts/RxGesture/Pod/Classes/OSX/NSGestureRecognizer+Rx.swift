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

import AppKit
import RxSwift
import RxCocoa

private class GestureTarget {

    fileprivate var retainedSelf: GestureTarget?

    init() {
        retainedSelf = self
    }

    func dispose() {
        retainedSelf = nil
    }

    @objc func controlEvent() {
        handler?()
    }

    var handler: (() -> Void)?
}

extension Reactive where Base: NSGestureRecognizer {

    /**
     Reactive wrapper for gesture recognizer events.
     */
    public var event: ControlEvent<NSGestureRecognizer> {
        let source: Observable<NSGestureRecognizer> = Observable.create {observer in
            MainScheduler.ensureExecutingOnScheduler()

            let control = self.base
            control.isEnabled = true

            let gestureTarget = GestureTarget()
            gestureTarget.handler = {
                observer.on(.next(control))
            }

            control.target = gestureTarget
            control.action = #selector(GestureTarget.controlEvent)

            return Disposables.create {
                if let view = control.view {
                    view.removeGestureRecognizer(control)
                }
                gestureTarget.dispose()
            }
        }.takeUntil(self.deallocated)

        return ControlEvent(events: source)
    }

}
