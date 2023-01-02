//
//  UIViewController+SideNavigationController.swift
//  SideNavigationController
//
//  Created by Benoit BRIATTE on 13/03/2017.
//  Copyright © 2017 Digipolitan. All rights reserved.
//

import UIKit

public extension UIViewController {

    var sideNavigationController: SideNavigationController? {
        var current = self
        while let parent = current.parent {
            if let side = parent as? SideNavigationController {
                return side
            }
            current = parent
        }
        return nil
    }
}
