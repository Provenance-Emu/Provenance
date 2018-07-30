//  Action.swift
//  XLActionController ( https://github.com/xmartlabs/XLActionController )
//
//  Copyright (c) 2015 Xmartlabs ( http://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation
import UIKit

public enum ActionStyle {
    case `default`
    case cancel
    case destructive
}

public struct Action<T> {

    public var enabled: Bool
    public var executeImmediatelyOnTouch = false

    public fileprivate(set) var data: T?
    public fileprivate(set) var style = ActionStyle.default
    public fileprivate(set) var handler: ((Action<T>) -> Void)?

    public init(_ data: T?, style: ActionStyle, executeImmediatelyOnTouch: Bool = false, handler: ((Action<T>) -> Void)?) {
        enabled = true
        self.executeImmediatelyOnTouch = executeImmediatelyOnTouch
        self.data = data
        self.style = style
        self.handler = handler
    }

}
