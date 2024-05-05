//
//  SliderCell.swift
//  QuickTableViewController
//
//  Created by Aaron on 10/07/2018.
//  Copyright (c) 2018 getaaron.
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
#if os(iOS)

import UIKit

public protocol SliderRowCompatible: Row, RowStyle {
    var value: Float { get set }
    var valueLimits: (min: Float, max: Float) { get }
    var valueImages: (min: Icon?, max: Icon?) { get }
}

extension QuickTableViewController: SliderCellDelegate {
    // MARK: - SliderCellDelegate

    public func sliderCell(_ cell: SliderCell, didChangeValue newValue: Float) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let row = tableContents[indexPath.section].rows[indexPath.row] as? SliderRowCompatible
        else {
            return
        }
        row.value = newValue
    }
}


    /// The `SliderCellDelegate` protocol allows the adopting delegate to respond to the UI interaction. Not available on tvOS.
    @available(tvOS, unavailable, message: "SliderCellDelegate is not available on tvOS.")
    public protocol SliderCellDelegate: AnyObject {
        /// Tells the delegate that the slider value has changed.
        func sliderCell(_ cell: SliderCell, didChangeValue newValue: Float)
    }

    /// A `UITableViewCell` subclass that shows a `UISlider`. Not available on tvOS.
    @available(tvOS, unavailable, message: "SliderCell is not available on tvOS.")
    open class SliderCell: UITableViewCell, Configurable {
        var row:  SliderRowCompatible?

        /// A `UISlider`.
        public private(set) lazy var slider: UISlider = {
            let control = UISlider()
            control.addTarget(self, action: #selector(SliderCell.didChangeValue(_:)), for: .valueChanged)
            return control
        }()

        /// The slider cell's delegate object, which should conform to `SliderCellDelegate`. Not available on tvOS.
        open weak var delegate: SliderCellDelegate?

        // MARK: - Initializer

        /**
         Overrides `UITableViewCell`'s designated initializer.

         - parameter style:           A constant indicating a cell style.
         - parameter reuseIdentifier: A string used to identify the cell object if it is to be reused for drawing multiple rows of a table view.

         - returns: An initialized `SliderCell` object.
         */
        public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            contentView.addSubview(slider)
        }

        /**
         Overrides the designated initializer that returns an object initialized from data in a given unarchiver.

         - parameter aDecoder: An unarchiver object.

         - returns: `self`, initialized using the data in decoder.
         */
        public required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            contentView.addSubview(slider)
        }

        // MARK: - Configurable

        /// Set up the slider control with the provided row.
        open func configure(with row: Row & RowStyle) {
            if let row = row as? SliderRowCompatible {
                self.row = row
                slider.minimumValue = row.valueLimits.min
                slider.maximumValue = row.valueLimits.max
				#if !targetEnvironment(macCatalyst)
                slider.minimumValueImage = row.valueImages.min?.image
                slider.maximumValueImage = row.valueImages.max?.image
				#endif
                slider.setValue(row.value, animated: false)
            }
            
            guard let textLabel = textLabel else {
                return
            }

            textLabel.translatesAutoresizingMaskIntoConstraints = false
            textLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor).isActive = true

            slider.translatesAutoresizingMaskIntoConstraints = false
            slider.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 20).isActive = true
            slider.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor).isActive = true

            if let detailTextLabel = detailTextLabel {
                detailTextLabel.translatesAutoresizingMaskIntoConstraints = false
                contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 69).isActive = true
                detailTextLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor).isActive = true
                detailTextLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor).isActive = true
                detailTextLabel.topAnchor.constraint(equalTo: topAnchor, constant: 32).isActive = true
                detailTextLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true
                textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12).isActive = true
                slider.topAnchor.constraint(equalTo: textLabel.topAnchor, constant: -5).isActive = true
            } else {
                contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
                textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0).isActive = true
                textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true
                slider.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0).isActive = true
            }
        }

        // MARK: - Private

        @objc
        private func didChangeValue(_ sender: UISlider) {
            self.row?.value = sender.value
            delegate?.sliderCell(self, didChangeValue: sender.value)
        }
    }
#endif
