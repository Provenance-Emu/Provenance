//
//  PVSideMenu.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import SideMenu

class PVSideMenu: SideMenuNavigationController {

     override init(rootViewController: UIViewController, settings: SideMenuSettings = SideMenuSettings()) {
         super.init(rootViewController: rootViewController, settings: settings)

         menuWidth = 325
         isNavigationBarHidden = false
     }

     convenience init(rootViewController: UIViewController) {
         let settings: SideMenuSettings = {
             var set = SideMenuSettings()
             set.presentationStyle = .viewSlideOutMenuIn
             return set
         }()
         self.init(rootViewController: rootViewController, settings: settings)
     }

     required init?(coder aDecoder: NSCoder) {
         fatalError("init(coder:) has not been implemented")
     }
 }
