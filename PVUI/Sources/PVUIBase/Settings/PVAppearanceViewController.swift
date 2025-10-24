//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVAppearanceViewController.swift
//  Provenance
//
//  Created by Marcel Voß on 22.09.16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVSupport
#if canImport(UIKit)
import UIKit
#endif
import PVSettings

public final class PVAppearanceViewController: UITableViewController {
    #if os(iOS)
        var showSearchbarSwitch: UISwitch?
        var hideTitlesSwitch: UISwitch?
        var recentlyPlayedSwitch: UISwitch?
        var saveStatesSwitch: UISwitch?
    #endif

    public override func viewDidLoad() {
        super.viewDidLoad()
        #if os(iOS)

            hideTitlesSwitch = UISwitch()
            hideTitlesSwitch?.isOn = Defaults[.showGameTitles]
            hideTitlesSwitch?.addTarget(self, action: #selector(PVAppearanceViewController.switchChangedValue(_:)), for: .valueChanged)

            showSearchbarSwitch = UISwitch()
            showSearchbarSwitch?.isOn = Defaults[.showSearchbar]
            showSearchbarSwitch?.addTarget(self, action: #selector(PVAppearanceViewController.switchChangedValue(_:)), for: .valueChanged)
        
            recentlyPlayedSwitch = UISwitch()
            recentlyPlayedSwitch?.isOn = Defaults[.showRecentGames]
            recentlyPlayedSwitch?.addTarget(self, action: #selector(PVAppearanceViewController.switchChangedValue(_:)), for: .valueChanged)

            saveStatesSwitch = UISwitch()
            saveStatesSwitch?.isOn = Defaults[.showRecentSaveStates]
            saveStatesSwitch?.addTarget(self, action: #selector(PVAppearanceViewController.switchChangedValue(_:)), for: .valueChanged)
        #endif
    }

    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    #if os(iOS)
        @objc func switchChangedValue(_ switchItem: UISwitch) {
            if switchItem == hideTitlesSwitch {
                Defaults[.showGameTitles] = switchItem.isOn
            } else if switchItem == recentlyPlayedSwitch {
                Defaults[.showRecentGames] = switchItem.isOn
            } else if switchItem == saveStatesSwitch {
                Defaults[.showRecentSaveStates] = switchItem.isOn
            } else if switchItem == showSearchbarSwitch {
                Defaults[.showSearchbar] = switchItem.isOn
            }
            NotificationCenter.default.post(name: NSNotification.Name("kInterfaceDidChangeNotification"), object: nil)
        }

    #endif

    // MARK: - Table view data source

    public override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    public override func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        return "Game Library Appearance"
    }

    public override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 3
        }
        return 0
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: "appearanceCell")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "appearanceCell")
        }
        #if os(tvOS)
            self.tableView.backgroundColor = .black
            self.tableView.mask = nil
        #endif
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell?.textLabel?.text = "Show Game Titles"
                #if os(tvOS)
                    cell?.detailTextLabel?.text = Defaults[.showGameTitles] ? "On" : "Off"
                #else
                    cell?.accessoryView = hideTitlesSwitch
                #endif
            } else if indexPath.row == 1 {
                cell?.textLabel?.text = "Show Recently Played Games"
                #if os(tvOS)
                    cell?.detailTextLabel?.text = Defaults[.showRecentGames] ? "On" : "Off"
                #else
                    cell?.accessoryView = recentlyPlayedSwitch
                #endif
            } else if indexPath.row == 2 {
                cell?.textLabel?.text = "Show Recent Save States"
#if os(tvOS)
                cell?.detailTextLabel?.text = Defaults[.showRecentSaveStates] ? "On" : "Off"
#else
                cell?.accessoryView = saveStatesSwitch
#endif
            } else if indexPath.row == 4 {
            cell?.textLabel?.text = "Show Search Bar"
            #if os(tvOS)
                cell?.detailTextLabel?.text = Defaults[.showSearchbar] ? "On" : "Off"
            #else
                cell?.accessoryView = showSearchbarSwitch
            #endif
        }
        }
        cell?.selectionStyle = .none
        return cell ?? UITableViewCell()
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        #if os(tvOS)
            let cell: UITableViewCell? = tableView.cellForRow(at: indexPath)

        if indexPath.section == 0 {
                if indexPath.row == 0 {
                    Defaults[.showGameTitles] = !Defaults[.showGameTitles]
                    cell?.detailTextLabel?.text = Defaults[.showGameTitles] ? "On" : "Off"
                } else if indexPath.row == 1 {
                    Defaults[.showRecentGames] = !Defaults[.showRecentGames]
                    cell?.detailTextLabel?.text = Defaults[.showRecentGames] ? "On" : "Off"
                } else if indexPath.row == 2 {
                    Defaults[.showRecentSaveStates] = !Defaults[.showRecentSaveStates]
                    cell?.detailTextLabel?.text = Defaults[.showRecentGames] ? "On" : "Off"
                } else if indexPath.row == 3 {
                    Defaults[.showSearchbar] = !Defaults[.showSearchbar]
                    cell?.detailTextLabel?.text = Defaults[.showSearchbar] ? "On" : "Off"
                }
            }
        #endif
    }
}
