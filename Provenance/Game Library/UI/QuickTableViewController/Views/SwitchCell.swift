//
//  SwitchCell.swift
//  QuickTableViewController
//
//  Created by Ben on 03/09/2015.
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

/// The `SwitchCellDelegate` protocol allows the adopting delegate to respond to the UI interaction. Not available on tvOS.
@available(tvOS, unavailable, message: "SwitchCellDelegate is not available on tvOS.")
public protocol SwitchCellDelegate: class {
  /// Tells the delegate that the switch control is toggled.
  func switchCell(_ cell: SwitchCell, didToggleSwitch isOn: Bool)
}


/// A `UITableViewCell` subclass that shows a `UISwitch` as the `accessoryView`.
open class SwitchCell: UITableViewCell, Configurable {

  #if os(iOS)

  /// A `UISwitch` as the `accessoryView`. Not available on tvOS.
  @available(tvOS, unavailable, message: "switchControl is not available on tvOS.")
  public private(set) lazy var switchControl: UISwitch = {
    let control = UISwitch()
    control.addTarget(self, action: #selector(SwitchCell.didToggleSwitch(_:)), for: .valueChanged)
    return control
  }()

  #endif

  /// The switch cell's delegate object, which should conform to `SwitchCellDelegate`. Not available on tvOS.
  @available(tvOS, unavailable, message: "SwitchCellDelegate is not available on tvOS.")
  open weak var delegate: SwitchCellDelegate?

  // MARK: - Initializer

  /**
   Overrides `UITableViewCell`'s designated initializer.

   - parameter style:           A constant indicating a cell style.
   - parameter reuseIdentifier: A string used to identify the cell object if it is to be reused for drawing multiple rows of a table view.

   - returns: An initialized `SwitchCell` object.
   */
  public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setUpAppearance()
  }

  /**
   Overrides the designated initializer that returns an object initialized from data in a given unarchiver.

   - parameter aDecoder: An unarchiver object.

   - returns: `self`, initialized using the data in decoder.
   */
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setUpAppearance()
  }

  // MARK: - Configurable

  /// Set up the switch control (iOS) or accessory type (tvOS) with the provided row.
  open func configure(with row: Row & RowStyle) {
    #if os(iOS)
      if let row = row as? SwitchRowCompatible {
        switchControl.isOn = row.switchValue
      }
      accessoryView = switchControl
    #elseif os(tvOS)
      accessoryView = nil
      accessoryType = row.accessoryType
    #endif
  }

  // MARK: - Private

  @available(tvOS, unavailable, message: "UISwitch is not available on tvOS.")
  @objc
  private func didToggleSwitch(_ sender: UISwitch) {
    delegate?.switchCell(self, didToggleSwitch: sender.isOn)
  }

  private func setUpAppearance() {
    textLabel?.numberOfLines = 0
    detailTextLabel?.numberOfLines = 0
  }

}
