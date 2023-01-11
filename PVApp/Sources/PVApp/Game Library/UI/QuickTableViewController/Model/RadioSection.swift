//
//  RadioSection.swift
//  QuickTableViewController
//
//  Created by Ben on 17/08/2017.
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

import Foundation

/// A section that allows only one option selected in a table view.
open class RadioSection: Section {

  // MARK: - Initializer

  /// Initializes a section with a title, containing rows and an optional footer.
  public init(title: String?, options: [OptionRowCompatible], footer: String? = nil) {
    self.options = options
    super.init(title: title, rows: [], footer: footer)
  }

  private override init(title: String?, rows: [Row & RowStyle], footer: String? = nil) {
    fatalError("init with title, rows, and footer is not supported")
  }

  // MARK: - Section

  /// The array of rows in the section.
  open override var rows: [Row & RowStyle] {
    get {
      return options
    }
    set {
      options = newValue as? [OptionRowCompatible] ?? options
    }
  }

  // MARK: - RadioSection

  /// A boolean that indicates whether there's always one option selected.
  open var alwaysSelectsOneOption: Bool = false {
    didSet {
      if alwaysSelectsOneOption && selectedOption == nil {
        options.first?.isSelected = true
      }
    }
  }

  /// The array of options in the section. It's identical to the `rows`.
  open private(set) var options: [OptionRowCompatible]

  /// Returns the selected index, or nil when nothing is selected.
  open var indexOfSelectedOption: Int? {
    return options.firstIndex { $0.isSelected }
  }

  /// Returns the selected option row, or nil when nothing is selected.
  open var selectedOption: OptionRowCompatible? {
    if let index = indexOfSelectedOption {
      return options[index]
    } else {
      return nil
    }
  }

  /// Toggle the selection of the given option and keep options mutually exclusive.
  /// If `alwaysSelectOneOption` is set to true, it will not deselect the current selection.
  ///
  /// - Parameter option: The option to flip the `isSelected` state.
  /// - Returns: The indexes of changed options.
  open func toggle(_ option: OptionRowCompatible) -> IndexSet {
    if option.isSelected && alwaysSelectsOneOption {
      return []
    }

    defer {
      option.isSelected = !option.isSelected
    }

    if option.isSelected {
      // Deselect the selected option.
      return options.firstIndex(where: { $0 === option }).map { [$0] } ?? []
    }

    var toggledIndexes: IndexSet = []

    for (index, element) in options.enumerated() {
      switch element {
      case let target where target === option:
        toggledIndexes.insert(index)
      case _ where element.isSelected:
        toggledIndexes.insert(index)
        element.isSelected = false
      default:
        break
      }
    }

    return toggledIndexes
  }

}
