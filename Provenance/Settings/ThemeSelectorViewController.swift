//
//  ThemeSelectorViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/26/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

#if os(iOS)
    @available(tvOS, unavailable, message: "SliderCellDelegate is not available on tvOS.")
    @available(iOS 9.0, *)
    class ThemeSelectorViewController: UITableViewController {
        override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
            return section == 0 ? 2 : 0
        }

        override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

            let currentTheme = Theme.currentTheme

            if indexPath.row == 0 {
                cell.textLabel?.text = Themes.light.rawValue
                cell.accessoryType = currentTheme.theme == .light ? .checkmark : .none
            } else if indexPath.row == 1 {
                cell.textLabel?.text = Themes.dark.rawValue
                cell.accessoryType = currentTheme.theme == .dark ? .checkmark : .none
            }

            return cell
        }

        override func tableView(_ tableView: UITableView, didSelectRowAt _: IndexPath) {
            //        if indexPath.row == 0 {
            //            Theme.currentTheme = Theme.lightTheme
            //            PVSettingsModel.shared.theme = .light
            //        } else if indexPath.row == 1 {
            //            Theme.currentTheme = Theme.darkTheme
            //            PVSettingsModel.shared.theme = .dark
            //        }

            tableView.reloadData()
        }
    }
#endif
