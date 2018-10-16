//
//  RootViewController.swift
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

internal final class RootViewController: QuickTableViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    let titleLabel = UILabel()
    titleLabel.text = "QuickTableViewController"
    titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
    title = " "
    navigationItem.titleView = titleLabel

    tableContents = [
      Section(title: "Default", rows: [
        NavigationRow(title: "Use default cell types", subtitle: .none, action: { [weak self] _ in
          self?.navigationController?.pushViewController(DefaultViewController(), animated: true)
        })
      ]),

      Section(title: "Customization", rows: [
        NavigationRow(title: "Use custom cell types", subtitle: .none, action: { [weak self] _ in
          self?.navigationController?.pushViewController(CustomizationViewController(), animated: true)
        })
      ]),

      Section(title: "UIAppearance", rows: [
        NavigationRow(title: "UILabel customization", subtitle: .none, action: { [weak self] _ in
          self?.navigationController?.pushViewController(AppearanceViewController(), animated: true)
        })
      ])
    ]
  }

}
