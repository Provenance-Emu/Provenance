//
//  SliderRow.swift
//  QuickTableViewController
//
//  Created by Aaron on 10/07/2018.
//  Copyright (c) 2015 getaaron.
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
#if !os(tvOS)

import UIKit

/// A class that represents a row with a switch.
open class SliderRow<T>: SliderRowCompatible, Equatable where T: SliderCell {
    // MARK: - Initializer

    /// Initializes a `SliderRow` with a title, a value and an action closure.
    public init(
        text: String = "",
        detailText: DetailText? = nil,
        value: Float,
        valueLimits: (min: Float, max: Float),
        valueImages: (min: Icon?, max: Icon?),
        customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil,
        action: ((Row) -> Void)?
    ) {
        self.text = text
        self.detailText = detailText
        self.value = value
        self.valueLimits = valueLimits
        self.valueImages = valueImages
        customize = customization
        self.action = action
    }

    // MARK: - SliderRowCompatible

    /// The value of the slider.
    public var value: Float {
        didSet {
            guard value != oldValue else {
                return
            }
            DispatchQueue.main.async {
                self.action?(self)
            }
        }
    }

    /// The maximum value icon of the slid
    public var valueLimits: (min: Float, max: Float)
    public var valueImages: (min: Icon?, max: Icon?)

    // MARK: - Row

    /// The text of the row.
    public let text: String

    /// The detail text of the row.
    public let detailText: DetailText?

    /// A closure that will be invoked when the `switchValue` is changed.
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
    
    /// The minimum value icon of the slider.
    public var icon: Icon? {
        return nil
//        return valueImages.min
    }

    /// The default accessory type is `.none`.
    public let accessoryType: UITableViewCell.AccessoryType = .none

    /// The `SliderRow` should not be selectable.
    public let isSelectable = false

    /// The additional customization during cell configuration.
    public let customize: ((UITableViewCell, Row & RowStyle) -> Void)?

    // MARK: - Equatable

    /// Returns true iff `lhs` and `rhs` have equal titles, switch values, and icons.
    public static func == (lhs: SliderRow, rhs: SliderRow) -> Bool {
        return
            lhs.text == rhs.text &&
            lhs.detailText == rhs.detailText &&
            lhs.value == rhs.value &&
            lhs.icon == rhs.icon
    }
}
#endif
