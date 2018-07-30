//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVAppearanceViewController.swift
//  Provenance
//
//  Created by Marcel Voß on 22.09.16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import UIKit

class PVAppearanceViewController: UITableViewController {

    #if os(iOS)
    var hideTitlesSwitch: UISwitch?
    var recentlyPlayedSwitch: UISwitch?
	var saveStatesSwitch: UISwitch?
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
#if os(iOS)
        let settings = PVSettingsModel.shared
        hideTitlesSwitch = UISwitch()
        hideTitlesSwitch?.isOn = settings.showGameTitles
        hideTitlesSwitch?.addTarget(self, action: #selector(PVAppearanceViewController.switchChangedValue(_:)), for: .valueChanged)

        recentlyPlayedSwitch = UISwitch()
        recentlyPlayedSwitch?.isOn = settings.showRecentGames
        recentlyPlayedSwitch?.addTarget(self, action: #selector(PVAppearanceViewController.switchChangedValue(_:)), for: .valueChanged)

		saveStatesSwitch = UISwitch()
		saveStatesSwitch?.isOn = settings.showRecentSaveStates
		saveStatesSwitch?.addTarget(self, action: #selector(PVAppearanceViewController.switchChangedValue(_:)), for: .valueChanged)
#endif
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

#if os(iOS)
    @objc func switchChangedValue(_ switchItem: UISwitch) {
        if switchItem == hideTitlesSwitch {
            PVSettingsModel.shared.showGameTitles = switchItem.isOn
		} else if switchItem == recentlyPlayedSwitch {
			PVSettingsModel.shared.showRecentGames = switchItem.isOn
		} else if switchItem == saveStatesSwitch {
            PVSettingsModel.shared.showRecentSaveStates = switchItem.isOn
        }

        NotificationCenter.default.post(name: NSNotification.Name("kInterfaceDidChangeNotification"), object: nil)
    }

#endif
// MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Appearance"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 3
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: "appearanceCell")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "appearanceCell")
        }
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell?.textLabel?.text = "Show Game Titles"
#if os(tvOS)
                cell?.detailTextLabel?.text = PVSettingsModel.shared.showGameTitles ? "On" : "Off"
#else
                cell?.textLabel?.textColor = Theme.currentTheme.settingsCellText
                cell?.accessoryView = hideTitlesSwitch
#endif
            } else if indexPath.row == 1 {
                cell?.textLabel?.text = "Show recently played games"
#if os(tvOS)
                cell?.detailTextLabel?.text = PVSettingsModel.shared.showRecentGames ? "On" : "Off"
#else
                cell?.textLabel?.textColor = Theme.currentTheme.settingsCellText
                cell?.accessoryView = recentlyPlayedSwitch
#endif
			} else if indexPath.row == 2 {
				cell?.textLabel?.text = "Show recent save states"
				#if os(tvOS)
				cell?.detailTextLabel?.text = PVSettingsModel.shared.showRecentSaveStates ? "On" : "Off"
				#else
				cell?.textLabel?.textColor = Theme.currentTheme.settingsCellText
				cell?.accessoryView = saveStatesSwitch
				#endif
			}
		}
        cell?.selectionStyle = .none
        return cell ?? UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
#if os(tvOS)
        let cell: UITableViewCell? = tableView.cellForRow(at: indexPath)
        let settings = PVSettingsModel.shared
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                settings.showGameTitles = !settings.showGameTitles
                cell?.detailTextLabel?.text = settings.showGameTitles ? "On" : "Off"
            } else if indexPath.row == 1 {
                settings.showRecentGames = !settings.showRecentGames
                cell?.detailTextLabel?.text = settings.showRecentGames ? "On" : "Off"
			} else if indexPath.row == 2 {
				settings.showRecentSaveStates = !settings.showRecentSaveStates
				cell?.detailTextLabel?.text = settings.showRecentSaveStates ? "On" : "Off"
			}
		}
#endif
    }
}
