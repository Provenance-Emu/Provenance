//
//  AppearanceViewController.swift
//  Example-iOS
//
//  Created by Ben on 30/01/2018.
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

internal final class AppearanceViewController: QuickTableViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "UIAppearance"

    // Register the nib files to the table view for UIAppearance customization (in AppDelegate) to work.
    tableView.register(UINib(nibName: "SwitchCell", bundle: .main), forCellReuseIdentifier: "SwitchCell")
    tableView.register(UINib(nibName: "TapActionCell", bundle: .main), forCellReuseIdentifier: "TapActionCell")
    tableView.register(UINib(nibName: "UITableViewCell", bundle: .main), forCellReuseIdentifier: "UITableViewCell.subtitle")
    tableView.register(UINib(nibName: "OptionCell", bundle: .main), forCellReuseIdentifier: "UITableViewCell")

    tableContents = [
      Section(title: "Switch", rows: [
        SwitchRow(title: "SwitchCell", switchValue: true, action: { _ in })
      ]),

      Section(title: "Tap Action", rows: [
        TapActionRow(title: "TapActionCell", action: { _ in })
      ]),

      Section(title: "Navigation", rows: [
        NavigationRow(title: "UITableViewCell", subtitle: .belowTitle(".subtitle"), action: { _ in })
      ]),

      RadioSection(title: "Radio Buttons", options: [
        OptionRow(title: "UITableViewCell", isSelected: true, action: { _ in })
      ])
    ]
  }

}
