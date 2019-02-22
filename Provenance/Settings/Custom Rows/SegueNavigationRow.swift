//
//  SegueNavigationRow.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import QuickTableViewController

final class SegueNavigationRow: NavigationRow<SystemSettingsCell> {
    weak var viewController: UIViewController?

    required init(text: String,
                  detailText: DetailText = .none,
                  viewController: UIViewController,
                  segue: String,
                  customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil) {
        self.viewController = viewController

        super.init(text: text, detailText: detailText, icon: nil, customization: customization) { [weak viewController] _ in
            guard let viewController = viewController else { return }

            viewController.performSegue(withIdentifier: segue, sender: nil)
        }
    }
}
