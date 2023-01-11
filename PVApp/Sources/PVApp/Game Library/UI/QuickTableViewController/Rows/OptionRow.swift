//
//  OptionRow.swift
//  QuickTableViewController
//
//  Created by Ben on 30/07/2017.
//  Copyright © 2017 bcylin.
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

/// A class that represents a row of selectable option.
open class OptionRow<T: UITableViewCell>: OptionRowCompatible, Equatable {

  // MARK: - Initializer

  /// Initializes an `OptionRow` with a text, a selection state and an action closure.
  /// The detail text, icon, and the customization closure are optional.
  public init(
    text: String,
    detailText: DetailText? = nil,
    isSelected: Bool,
    icon: Icon? = nil,
    customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil,
    action: ((Row) -> Void)?
  ) {
    self.text = text
    self.detailText = detailText
    self.isSelected = isSelected
    self.icon = icon
    self.customize = customization
    self.action = action
  }

  // MARK: - OptionRowCompatible

  /// The state of selection.
  public var isSelected: Bool = false {
    didSet {
      guard isSelected != oldValue else {
        return
      }
      DispatchQueue.main.async {
        self.action?(self)
      }
    }
  }

  // MARK: - Row

  /// The text of the row.
  public let text: String

  /// The detail text of the row.
  public let detailText: DetailText?

  /// A closure that will be invoked when the `isSelected` is changed.
  public let action: ((Row) -> Void)?

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

  /// Returns `.checkmark` when the row is selected, otherwise returns `.none`.
  public var accessoryType: UITableViewCell.AccessoryType {
    return isSelected ? .checkmark : .none
  }

  /// `OptionRow` is always selectable.
  public let isSelectable: Bool = true

  /// Additional customization during cell configuration.
  public let customize: ((UITableViewCell, Row & RowStyle) -> Void)?

  // MARK: - Equatable

  /// Returns true iff `lhs` and `rhs` have equal titles, detail texts, selection states, and icons.
  public static func == (lhs: OptionRow, rhs: OptionRow) -> Bool {
    return
      lhs.text == rhs.text &&
      lhs.detailText == rhs.detailText &&
      lhs.isSelected == rhs.isSelected &&
      lhs.icon == rhs.icon
  }

}
