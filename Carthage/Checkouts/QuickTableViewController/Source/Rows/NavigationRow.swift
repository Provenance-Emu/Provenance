//
//  NavigationRow.swift
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

/// A class that represents a row that triggers certain navigation when selected.
open class NavigationRow<T: UITableViewCell>: NavigationRowCompatible, Equatable {

  // MARK: - Initializer

  /// Initializes a `NavigationRow` with a title and a subtitle.
  /// The icon, customization and action closures are optional.
  public init(
    title: String,
    subtitle: Subtitle,
    icon: Icon? = nil,
    customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil,
    action: ((Row) -> Void)? = nil
  ) {
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self.customize = customization
    self.action = action
  }

  // MARK: - Row

  /// The title text of the row.
  public let title: String

  /// The subtitle text of the row.
  public let subtitle: Subtitle?

  /// A closure that will be invoked when the row is selected.
  public let action: ((Row) -> Void)?

  // MARK: - RowStyle

  /// The type of the table view cell to display the row.
  public let cellType: UITableViewCell.Type = T.self

  /// Returns the reuse identifier of the table view cell to display the row.
  public var cellReuseIdentifier: String {
    return T.reuseIdentifier + (subtitle?.style.stringValue ?? "")
  }

  /// Returns the table view cell style for the specified subtitle.
  public var cellStyle: UITableViewCellStyle {
    return subtitle?.style ?? .default
  }

  /// The icon of the row.
  public let icon: Icon?

  /// Returns `.disclosureIndicator` when action is not nil, otherwise returns `.none`.
  public var accessoryType: UITableViewCellAccessoryType {
    return (action == nil) ? .none : .disclosureIndicator
  }

  /// The `NavigationRow` is selectable when action is not nil.
  public var isSelectable: Bool {
    return action != nil
  }

  /// The additional customization during cell configuration.
  public let customize: ((UITableViewCell, Row & RowStyle) -> Void)?

  // MARK: Equatable

  /// Returns true iff `lhs` and `rhs` have equal titles, subtitles and icons.
  public static func == (lhs: NavigationRow, rhs: NavigationRow) -> Bool {
    return
      lhs.title == rhs.title &&
      lhs.subtitle == rhs.subtitle &&
      lhs.icon == rhs.icon
  }

}
