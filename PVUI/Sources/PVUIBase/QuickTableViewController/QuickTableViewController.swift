//
//  QuickTableViewController.swift
//  QuickTableViewController
//
//  Created by Ben on 25/08/2015.
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
#if canImport(UIKit)
import UIKit
public typealias TableView = UITableView
public typealias TableViewDataSource = UITableViewDataSource
public typealias TableViewDelegate = UITableViewDelegate
public typealias TableViewCell = UITableViewCell
#elseif canImport(AppKit)
import AppKit
public typealias TableView = NSTableView
public typealias TableViewDataSource = NSTableViewDataSource
public typealias TableViewDelegate = NSTableViewDelegate
public typealias TableViewCell = NSTableViewCell
#endif


/// A table view controller that shows `tableContents` as formatted sections and rows.
open class QuickTableViewController: UIViewController, TableViewDataSource, TableViewDelegate {

  /// A Boolean value indicating if the controller clears the selection when the collection view appears.
  open var clearsSelectionOnViewWillAppear = true

  private var _selected:IndexPath?

  /// Returns the table view managed by the controller object.
    #if os(iOS) || os(macOS)
        open var tableView: TableView! = {
            return TableView(frame: .zero, style: .insetGrouped)
        }()
    #else
        open var tableView: TableView! = TableView(frame: .zero, style: .grouped)
    #endif

  /// The layout of sections and rows to display in the table view.
  open var tableContents: [Section] = [] {
    didSet {
        Task.detached { @MainActor in
            self.tableView.reloadData()
        }
    }
  }

  // MARK: - Initialization

  /// Initializes a table view controller to manage a table view of a given style.
  ///
  /// - Parameter style: A constant that specifies the style of table view that the controller object is to manage.
  public init(style: TableView.Style) {
    super.init(nibName: nil, bundle: nil)
    tableView = TableView(frame: .zero, style: style)
  }

  /// Returns a newly initialized view controller with the nib file in the specified bundle.
  ///
  /// - Parameters:
  ///   - nibNameOrNil: The name of the nib file to associate with the view controller.
  ///   - nibBundleOrNil: The bundle in which to search for the nib file.
  public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
  }

  /// Returns an object initialized from data in a given unarchiver.
  ///
  /// - Parameter coder: An unarchiver object.
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  deinit {
    tableView.dataSource = nil
    tableView.delegate = nil
  }

  // MARK: - UIViewController

  open override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(tableView)
    tableView.frame = view.bounds
    tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    tableView.rowHeight = TableView.automaticDimension
    tableView.estimatedRowHeight = 44
    tableView.dataSource = self
    tableView.delegate = self
    #if os(tvOS)
    // leave some room on the left and right for tvOS focus animation scaling
    tableView.layoutMargins = UIEdgeInsets(top:0, left:16, bottom:0, right:16)
    #endif
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let indexPath = tableView.indexPathForSelectedRow, clearsSelectionOnViewWillAppear {
      tableView.deselectRow(at: indexPath, animated: true)
    }
  }

  // MARK: - TableViewDataSource

  open func numberOfSections(in tableView: TableView) -> Int {
    return tableContents.count
  }

  open func tableView(_ tableView: TableView, numberOfRowsInSection section: Int) -> Int {
    return tableContents[section].rows.count
  }

  open func tableView(_ tableView: TableView, titleForHeaderInSection section: Int) -> String? {
    return tableContents[section].title
  }

  open func tableView(_ tableView: TableView, cellForRowAt indexPath: IndexPath) -> TableViewCell {
    let row = tableContents[indexPath.section].rows[indexPath.row]
    let cell =
      tableView.dequeueReusableCell(withIdentifier: row.cellReuseIdentifier) ??
      row.cellType.init(style: row.cellStyle, reuseIdentifier: row.cellReuseIdentifier)

    cell.defaultSetUp(with: row)
    (cell as? Configurable)?.configure(with: row)
    #if os(iOS)
      (cell as? SwitchCell)?.delegate = self
    #endif
      
      Task.detached {
          await row.customize?(cell, row)
      }

    return cell
  }

  open func tableView(_ tableView: TableView, titleForFooterInSection section: Int) -> String? {
    return tableContents[section].footer
  }

  // MARK: - TableViewDelegate

  open func tableView(_ tableView: TableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
    return tableContents[indexPath.section].rows[indexPath.row].isSelectable
  }

  open func tableView(_ tableView: TableView, didSelectRowAt indexPath: IndexPath) {
    let section = tableContents[indexPath.section]
    let row = section.rows[indexPath.row]

    _selected = indexPath   // remember this so we can restore focus after a reloadData
    let contentOffset = tableView.contentOffset

    switch (section, row) {
    case let (radio as RadioSection, option as OptionRowCompatible):
      let changes: [IndexPath] = radio.toggle(option).map {
        IndexPath(row: $0, section: indexPath.section)
      }
      if changes.isEmpty {
        tableView.deselectRow(at: indexPath, animated: false)
      } else {
        tableView.reloadRows(at: changes, with: .none)
      }
      #if os(tvOS)
      DispatchQueue.main.async {
        tableView.layoutIfNeeded()
        tableView.setContentOffset(contentOffset, animated: false)
      }
      #endif

    case let (_, option as OptionRowCompatible):
      // Allow OptionRow to be used without RadioSection.
      option.isSelected = !option.isSelected
      tableView.reloadData()

    #if os(tvOS)
    case let (_, row as SwitchRowCompatible):
      // SwitchRow on tvOS behaves like OptionRow.
      row.switchValue = !row.switchValue
      tableView.reloadData()
      tableView.layoutIfNeeded()
      tableView.setContentOffset(contentOffset, animated: false)
    #endif

    case (_, is TapActionRowCompatible):
      tableView.deselectRow(at: indexPath, animated: true)
      // Avoid some unwanted animation when the action also involves table view reload.
      DispatchQueue.main.async {
        row.action?(row)
      }

    case let (_, row) where row.isSelectable:
      DispatchQueue.main.async {
        row.action?(row)
      }

    default:
      break
    }
  }

  #if os(iOS)
  public func tableView(_ tableView: TableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
    switch tableContents[indexPath.section].rows[indexPath.row] {
    case let row as NavigationRowCompatible:
      DispatchQueue.main.async {
        row.accessoryButtonAction?(row)
      }
    default:
      break
    }
  }
  #endif

#if os(tvOS)
    public func indexPathForPreferredFocusedView(in tableView: TableView) -> IndexPath? {
        // set the focus to what was last selected
        return _selected ?? IndexPath(row:0, section:0)
    }
#endif

}

#if os(iOS)
// MARK: - SwitchCellDelegate
extension QuickTableViewController: SwitchCellDelegate {
    public func switchCell(_ cell: SwitchCell, didToggleSwitch isOn: Bool) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let row = tableContents[indexPath.section].rows[indexPath.row] as? SwitchRowCompatible
        else {
            return
        }
        row.switchValue = isOn
    }
}
#endif
