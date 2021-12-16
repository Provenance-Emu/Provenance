//
//  DetailText.swift
//  QuickTableViewController
//
//  Created by bcylin on 31/12/2018.
//  Copyright © 2018 bcylin.
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

/// An enum that represents a detail text with `UITableViewCell.CellStyle`.
public enum DetailText: Equatable {

  /// Does not show a detail text in `UITableViewCell.CellStyle.default`.
  case none
  /// Shows the detail text in `UITableViewCell.CellStyle.subtitle`.
  case subtitle(String)
  /// Shows the detail text in `UITableViewCell.CellStyle.value1`.
  case value1(String)
  /// Shows the detail text in `UITableViewCell.CellStyle.value2`.
  case value2(String)

  /// Returns the corresponding table view cell style.
  public var style: UITableViewCell.CellStyle {
    switch self {
    case .none:     return .default
    case .subtitle: return .subtitle
    case .value1:   return .value1
    case .value2:   return .value2
    }
  }

  /// Returns the associated text of the case.
  public var text: String? {
    switch self {
    case .none:
      return nil
    case let .subtitle(text), let .value1(text), let .value2(text):
      return text
    }
  }

}
