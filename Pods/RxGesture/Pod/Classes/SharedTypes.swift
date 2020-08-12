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

import Foundation

#if os(iOS)
    import UIKit
    public typealias Touch = UITouch
    public typealias GestureRecognizer = UIGestureRecognizer
    #if swift(>=4.2)
        public typealias GestureRecognizerState = UIGestureRecognizer.State
    #else
        public typealias GestureRecognizerState = UIGestureRecognizerState
    #endif
    public typealias GestureRecognizerDelegate = UIGestureRecognizerDelegate
    public typealias View = UIView
    public typealias Point = CGPoint
#elseif os(OSX)
    import AppKit
    public typealias Touch = NSTouch
    public typealias GestureRecognizer = NSGestureRecognizer
    public typealias GestureRecognizerState = NSGestureRecognizer.State
    public typealias GestureRecognizerDelegate = NSGestureRecognizerDelegate
    public typealias View = NSView
    public typealias Point = NSPoint
#endif

public enum TargetView {
    /// The target view will be the gestureRecognizer's view
    case view

    /// The target view will be the gestureRecognizer's view's superview
    case superview

    /// The target view will be the gestureRecognizer's view's window
    case window

    /// The target view will be the given view
    case this(View)

    public func targetView(for gestureRecognizer: GestureRecognizer) -> View? {
        switch self {
        case .view:
            return gestureRecognizer.view
        case .superview:
            return gestureRecognizer.view?.superview
        case .window:
            #if os(iOS)
                return gestureRecognizer.view?.window
            #elseif os(OSX)
                return gestureRecognizer.view?.window?.contentView
            #endif
        case .this(let view):
            return view
        }
    }
}

extension GestureRecognizerState: CustomStringConvertible {
    public var description: String {
        return String(describing: type(of: self)) + {
            switch self {
            case .possible:   return ".possible"
            case .began:      return ".began"
            case .changed:    return ".changed"
            case .ended:      return ".ended"
            case .cancelled:  return ".cancelled"
            case .failed:     return ".failed"
            @unknown default: return ".failed"
            }
        }()
    }
}
