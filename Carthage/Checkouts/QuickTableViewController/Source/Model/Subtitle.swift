//
//  Subtitle.swift
//  QuickTableViewController
//
//  Created by Ben on 01/09/2015.
//  Copyright (c) 2015 bcylin.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit

/// An enum that represents a subtitle text with `UITableViewCellStyle`.
public enum Subtitle: Equatable {

  /// Does not show a subtitle as `UITableViewCellStyle.default`.
  case none
  /// Shows the associated text in `UITableViewCellStyle.subtitle`.
  case belowTitle(String)
  /// Shows the associated text in `UITableViewCellStyle.value1`.
  case rightAligned(String)
  /// Shows the associated text in `UITableViewCellStyle.value2`.
  case leftAligned(String)

  /// Returns the corresponding table view cell style.
  public var style: UITableViewCellStyle {
    switch self {
    case .none:          return .default
    case .belowTitle:    return .subtitle
    case .rightAligned:  return .value1
    case .leftAligned:   return .value2
    }
  }

  /// Returns the associated text of the case.
  public var text: String? {
    switch self {
    case let .belowTitle(text):   return text
    case let .rightAligned(text): return text
    case let .leftAligned(text):  return text
    default:                      return nil
    }
  }

  // MARK: Equatable

  /// Returns true iff `lhs` and `rhs` have equal texts in the same `Subtitle`.
  public static func == (lhs: Subtitle, rhs: Subtitle) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none):
      return true
    case let (.belowTitle(a), .belowTitle(b)):
      return a == b
    case let (.rightAligned(a), .rightAligned(b)):
      return a == b
    case let (.leftAligned(a), .leftAligned(b)):
      return a == b
    default:
      return false
    }
  }

}


internal extension UITableViewCellStyle {

  var stringValue: String {
    switch self {
    case .default:  return ".default"
    case .subtitle: return ".subtitle"
    case .value1:   return ".value1"
    case .value2:   return ".value2"
    }
  }

}
