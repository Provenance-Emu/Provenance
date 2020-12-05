//
//  PVTVTabBarController.swift
//  ProvenanceTV
//
//  Created by Dan Berglund on 2020-05-17.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

class PVTVTabBarController: UITabBarController {
    // MARK: - Keyboard actions

    public override var keyCommands: [UIKeyCommand]? {
        var sectionCommands = [UIKeyCommand]() /* TODO: .reserveCapacity(sectionInfo.count + 2) */

        #if targetEnvironment(simulator)
            let flags: UIKeyModifierFlags = [.control, .command]
        #else
            let flags: UIKeyModifierFlags = .command
        #endif
        
        let findCommand = UIKeyCommand(input: "f", modifierFlags: flags, action: #selector(PVTVTabBarController.searchAction), discoverabilityTitle: "Find…")
        sectionCommands.append(findCommand)

        let settingsCommand = UIKeyCommand(input: ",", modifierFlags: flags, action: #selector(PVTVTabBarController.settingsAction), discoverabilityTitle: "Settings")
        sectionCommands.append(settingsCommand)

        return sectionCommands
    }

    @objc
    func settingsAction() {
        selectedIndex = max(0, (viewControllers?.count ?? 1) - 1)
    }

    @objc
    func searchAction() {
        if let navVC = selectedViewController as? UINavigationController, let searchVC = navVC.viewControllers.first as? UISearchContainerViewController {
            // Reselect the search bar
            searchVC.searchController.searchBar.becomeFirstResponder()
            searchVC.searchController.searchBar.setNeedsFocusUpdate()
            searchVC.searchController.searchBar.updateFocusIfNeeded()
        } else {
            selectedIndex = 1
        }
    }
}
