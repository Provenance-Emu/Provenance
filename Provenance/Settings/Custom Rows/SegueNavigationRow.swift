//
//  SegueNavigationRow.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import QuickTableViewController

final class SegueNavigationRow :  NavigationRow<SystemSettingsCell> {
    weak var viewController : UIViewController?

    required init(title: String,
                  subtitle: Subtitle = .none,
                  viewController: UIViewController,
                  segue: String,
                  customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil) {
        self.viewController = viewController

        super.init(title: title, subtitle: subtitle, icon: nil, customization: customization) {[weak viewController] (row) in
            guard let viewController = viewController else {return}

            viewController.performSegue(withIdentifier: segue, sender: nil)
        }
    }
}
