//
//  DefaultViewController.swift
//  Example-iOS
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
import QuickTableViewController

internal final class DefaultViewController: QuickTableViewController {

  // MARK: - Properties

  private let debugging = Section(title: nil, rows: [NavigationRow(title: "", subtitle: .none)])

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "QuickTableViewController"

    let gear = #imageLiteral(resourceName: "iconmonstr-gear")
    let globe = #imageLiteral(resourceName: "iconmonstr-globe")
    let time = #imageLiteral(resourceName: "iconmonstr-time")

    tableContents = [
      Section(title: "Switch", rows: [
        SwitchRow(title: "Setting 1", switchValue: true, icon: .image(globe), action: didToggleSwitch()),
        SwitchRow(title: "Setting 2", switchValue: false, icon: .image(time), action: didToggleSwitch())
      ]),

      Section(title: "Tap Action", rows: [
        TapActionRow(title: "Tap action", action: showAlert())
      ]),

      Section(title: "Navigation", rows: [
        NavigationRow(title: "CellStyle.default", subtitle: .none, icon: .image(gear)),
        NavigationRow(title: "CellStyle", subtitle: .belowTitle(".subtitle"), icon: .image(globe)),
        NavigationRow(title: "CellStyle", subtitle: .rightAligned(".value1"), icon: .image(time), action: showDetail()),
        NavigationRow(title: "CellStyle", subtitle: .leftAligned(".value2"))
      ], footer: "UITableViewCellStyle.Value2 hides the image view."),

      RadioSection(title: "Radio Buttons", options: [
        OptionRow(title: "Option 1", isSelected: true, action: didToggleSelection()),
        OptionRow(title: "Option 2", isSelected: false, action: didToggleSelection()),
        OptionRow(title: "Option 3", isSelected: false, action: didToggleSelection())
      ], footer: "See RadioSection for more details."),

      debugging
    ]
  }

  // MARK: - UITableViewDataSource

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = super.tableView(tableView, cellForRowAt: indexPath)
    // Alter the cells created by QuickTableViewController
    return cell
  }

  // MARK: - Private Methods

  private func didToggleSelection() -> (Row) -> Void {
    return { [weak self] in
      if let option = $0 as? OptionRowCompatible {
        let state = "\(option.title) is " + (option.isSelected ? "selected" : "deselected")
        self?.showDebuggingText(state)
      }
    }
  }

  private func didToggleSwitch() -> (Row) -> Void {
    return { [weak self] in
      if let row = $0 as? SwitchRowCompatible {
        let state = "\(row.title) = \(row.switchValue)"
        self?.showDebuggingText(state)
      }
    }
  }

  private func showAlert() -> (Row) -> Void {
    return { [weak self] _ in
      let alert = UIAlertController(title: "Action Triggered", message: nil, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .cancel) { [weak self] _ in
        self?.dismiss(animated: true, completion: nil)
      })
      self?.present(alert, animated: true, completion: nil)
    }
  }

  private func showDetail() -> (Row) -> Void {
    return { [weak self] in
      let detail = $0.title + ($0.subtitle?.text ?? "")
      let controller = UIViewController()
      controller.view.backgroundColor = .white
      controller.title = detail
      self?.navigationController?.pushViewController(controller, animated: true)
      self?.showDebuggingText(detail + " is selected")
    }
  }

  private func showDebuggingText(_ text: String) {
    print(text)
    debugging.rows = [NavigationRow(title: text, subtitle: .none)]
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      self?.tableView.reloadData()
    }
  }

}
