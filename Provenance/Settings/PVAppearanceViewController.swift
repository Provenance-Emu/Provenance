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
    #endif
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Appearance"
#if os(iOS)
        let settings = PVSettingsModel.sharedInstance()
        hideTitlesSwitch = UISwitch()
        hideTitlesSwitch?.onTintColor = UIColor(red: 0.20, green: 0.45, blue: 0.99, alpha: 1.00)
        hideTitlesSwitch?.isOn = settings.showGameTitles
        hideTitlesSwitch?.addTarget(self, action: #selector(PVAppearanceViewController.switchChangedValue(_:)), for: .valueChanged)
        recentlyPlayedSwitch = UISwitch()
        recentlyPlayedSwitch?.onTintColor = UIColor(red: 0.20, green: 0.45, blue: 0.99, alpha: 1.00)
        recentlyPlayedSwitch?.isOn = settings.showRecentGames
        recentlyPlayedSwitch?.addTarget(self, action: #selector(PVAppearanceViewController.switchChangedValue(_:)), for: .valueChanged)
#endif
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

#if os(iOS)
    @objc func switchChangedValue(_ switchItem: UISwitch) {
        if switchItem == hideTitlesSwitch {
            PVSettingsModel.sharedInstance().showGameTitles = switchItem.isOn
        }
        else if switchItem == recentlyPlayedSwitch {
            PVSettingsModel.sharedInstance().showRecentGames = switchItem.isOn
        }

        NotificationCenter.default.post(name: NSNotification.Name("kInterfaceDidChangeNotification"), object: nil)
    }

#endif
// MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 2
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
                cell?.detailTextLabel?.text = PVSettingsModel.sharedInstance().showGameTitles ? "On" : "Off"
#else
                cell?.accessoryView = hideTitlesSwitch
#endif
            }
            else if indexPath.row == 1 {
                cell?.textLabel?.text = "Show recently played games"
#if os(tvOS)
                cell?.detailTextLabel?.text = PVSettingsModel.sharedInstance().showRecentGames ? "On" : "Off"
#else
                cell?.accessoryView = recentlyPlayedSwitch
#endif
            }
        }
        cell?.selectionStyle = .none
        return cell ?? UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
#if os(tvOS)
        let cell: UITableViewCell? = tableView.cellForRow(at: indexPath)
        let settings = PVSettingsModel.sharedInstance()
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                settings.showGameTitles = !settings.showGameTitles
                cell?.detailTextLabel?.text = settings.showGameTitles ? "On" : "Off"
            }
            else if indexPath.row == 1 {
                settings.showRecentGames = !settings.showRecentGames
                cell?.detailTextLabel?.text = settings.showRecentGames ? "On" : "Off"
            }
        }
#endif
    }
}
