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

  #if os(iOS)

  /// Designated initializer on iOS. Returns a `NavigationRow` with a text and a detail text.
  /// The icon, customization, action and accessory button action closures are optional.
  public init(
    text: String,
    detailText: DetailText,
    icon: Icon? = nil,
    customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil,
    action: ((Row) -> Void)? = nil,
    accessoryButtonAction: ((Row) -> Void)? = nil
  ) {
    self.text = text
    self.detailText = detailText
    self.icon = icon
    self.customize = customization
    self.action = action
    self.accessoryButtonAction = accessoryButtonAction
  }

  #elseif os(tvOS)

  /// Designated initializer on tvOS. Returns a `NavigationRow` with a text and a detail text.
  /// The icon, customization and action closures are optional.
  public init(
    text: String,
    detailText: DetailText,
    icon: Icon? = nil,
    customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil,
    action: ((Row) -> Void)? = nil
  ) {
    self.text = text
    self.detailText = detailText
    self.icon = icon
    self.customize = customization
    self.action = action
  }

  #endif

  // MARK: - Row

  /// The text of the row.
  public let text: String

  /// The detail text of the row.
  public let detailText: DetailText?

  /// A closure that will be invoked when the row is selected.
  public let action: ((Row) -> Void)?

  #if os(iOS)

  /// A closure that will be invoked when the accessory button is selected.
  public let accessoryButtonAction: ((Row) -> Void)?

  #endif

  // MARK: - RowStyle

  /// The type of the table view cell to display the row.
  public let cellType: UITableViewCell.Type = T.self

  /// Returns the reuse identifier of the table view cell to display the row.
  public var cellReuseIdentifier: String {
    return T.reuseIdentifier + (detailText?.style.stringValue ?? "")
  }

  /// Returns the table view cell style for the specified detail text.
  public var cellStyle: UITableViewCell.CellStyle {
    return detailText?.style ?? .default
  }

  /// The icon of the row.
  public let icon: Icon?

  /// Returns the accessory type with the disclosure indicator when `action` is not nil,
  /// and with the detail button when `accessoryButtonAction` is not nil.
  public var accessoryType: UITableViewCell.AccessoryType {
    #if os(iOS)
      switch (action, accessoryButtonAction) {
      case (nil, nil):      return .none
      case (.some, nil):    return .disclosureIndicator
      case (nil, .some):    return .detailButton
      case (.some, .some):  return .detailDisclosureButton
      }
    #elseif os(tvOS)
      return (action == nil) ? .none : .disclosureIndicator
    #endif
  }

  /// The `NavigationRow` is selectable when action is not nil.
  public var isSelectable: Bool {
    return action != nil
  }

  /// The additional customization during cell configuration.
  public let customize: ((UITableViewCell, Row & RowStyle) -> Void)?

  // MARK: Equatable

  /// Returns true iff `lhs` and `rhs` have equal titles, detail texts and icons.
  public static func == (lhs: NavigationRow, rhs: NavigationRow) -> Bool {
    return
      lhs.text == rhs.text &&
      lhs.detailText == rhs.detailText &&
      lhs.icon == rhs.icon
  }

}


internal extension UITableViewCell.CellStyle {

  var stringValue: String {
    switch self {
    case .default:    return ".default"
    case .subtitle:   return ".subtitle"
    case .value1:     return ".value1"
    case .value2:     return ".value2"
    @unknown default: return ".default"
    }
  }

}
