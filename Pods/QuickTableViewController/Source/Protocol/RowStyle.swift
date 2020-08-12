//
//  RowStyle.swift
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

/// Any type that conforms to this protocol carries the info for the UI.
public protocol RowStyle {

  /// The type of the table view cell to display the row.
  var cellType: UITableViewCell.Type { get }

  /// The reuse identifier of the table view cell to display the row.
  var cellReuseIdentifier: String { get }

  /// The style of the table view cell to display the row.
  var cellStyle: UITableViewCell.CellStyle { get }

  /// The icon of the row.
  var icon: Icon? { get }

  /// The type of standard accessory view the cell should use.
  var accessoryType: UITableViewCell.AccessoryType { get }

  /// The flag that indicates whether the table view cell should trigger the action when selected.
  var isSelectable: Bool { get }

  /// The additional customization during cell configuration.
  var customize: ((UITableViewCell, Row & RowStyle) -> Void)? { get }

}
