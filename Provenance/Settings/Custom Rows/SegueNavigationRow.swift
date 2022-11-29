//
//  SegueNavigationRow.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

final class SegueNavigationRow: NavigationRow<UITableViewCell> {
    weak var viewController: UIViewController?

    required init(text: String,
                  detailText: DetailText = .none,
                  icon: Icon? = nil,
                  viewController: UIViewController,
                  segue: String,
                  customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil) {
        self.viewController = viewController

        #if os(tvOS)
            super.init(text: text, detailText: detailText, icon: icon, customization: customization) { [weak viewController] _ in
                guard let viewController = viewController else { return }

                viewController.performSegue(withIdentifier: segue, sender: nil)
            }
        #else
            super.init(text: text, detailText: detailText, icon: icon, customization: customization, action: { [weak viewController] _ in
                guard let viewController = viewController else { return }

                viewController.performSegue(withIdentifier: segue, sender: nil)
            })
        #endif
    }
}
