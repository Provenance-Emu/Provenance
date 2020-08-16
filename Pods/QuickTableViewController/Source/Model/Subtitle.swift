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

@available(*, deprecated, message: "Use `DetailText` instead.")
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
  public var style: UITableViewCell.CellStyle {
    return detailText.style
  }

  /// Returns the associated text of the case.
  public var text: String? {
    return detailText.text
  }

  @available(*, deprecated, message: "The conversion between Subtitle and DetailText.")
  internal var detailText: DetailText {
    switch self {
    case .none:                   return .none
    case let .belowTitle(text):   return .subtitle(text)
    case let .rightAligned(text): return .value1(text)
    case let .leftAligned(text):  return .value2(text)
    }
  }

}


internal extension DetailText {

  @available(*, deprecated, message: "The conversion between DetailText and Subtitle.")
  var subtitle: Subtitle {
    switch self {
    case .none:               return .none
    case let .subtitle(text): return .belowTitle(text)
    case let .value1(text):   return .rightAligned(text)
    case let .value2(text):   return .leftAligned(text)
    }
  }

}
