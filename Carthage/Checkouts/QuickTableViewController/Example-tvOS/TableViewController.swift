//
//  TableViewController.swift
//  Example-tvOS
//
//  Created by Ben on 19/04/2018.
//  Copyright © 2018 bcylin.
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

final class TableViewController: QuickTableViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "QuickTableViewController"

    tableContents = [
      Section(title: "Switch", rows: [
        SwitchRow(title: "Setting 1", switchValue: true, action: showLog()),
        SwitchRow(title: "Setting 2", switchValue: false, action: showLog())
      ]),

      Section(title: "Tap Action", rows: [
        TapActionRow(title: "Tap action", action: showAlert())
      ]),

      Section(title: "Navigation", rows: [
        NavigationRow(title: "CellStyle.default", subtitle: .none, action: showDetail()),
        NavigationRow(title: "CellStyle", subtitle: .belowTitle(".subtitle"), action: showDetail()),
        NavigationRow(title: "CellStyle", subtitle: .rightAligned(".value1")),
        NavigationRow(title: "CellStyle", subtitle: .leftAligned(".value2"))
      ]),

      RadioSection(title: "Radio Buttons", options: [
        OptionRow(title: "Option 1", isSelected: true, action: showLog()),
        OptionRow(title: "Option 2", isSelected: false, action: showLog()),
        OptionRow(title: "Option 3", isSelected: false, action: showLog())
      ], footer: "See RadioSection for more details.")
    ]
  }

  // MARK: - Private

  private func showAlert() -> (Row) -> Void {
    return { [weak self] row in
      let alert = UIAlertController(
        title: row.title,
        message: row.subtitle.flatMap({ $0.text }),
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
      self?.present(alert, animated: true, completion: nil)
    }
  }

  private func showDetail() -> (Row) -> Void {
    return { [weak self] row in
      let controller = UIViewController()
      controller.title = row.title + (row.subtitle?.text ?? "")
      self?.navigationController?.pushViewController(controller, animated: true)
    }
  }

  private func showLog() -> (Row) -> Void {
    return {
      switch $0 {
      case let row as SwitchRowCompatible:
        print("\(row.title) = \(row.switchValue)")
      case let option as OptionRowCompatible where option.isSelected:
        print("\(option.title) is selected")
      default:
        break
      }
    }
  }

}
