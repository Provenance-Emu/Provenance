//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PViCadeControllerViewController.swift
//  Provenance
//
//  Created by James Addyman on 17/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

import UIKit

class PViCadeControllerViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
#if os(iOS)
        let currentTableView: UITableView? = tableView
        if let aFrame = currentTableView?.frame, let aStyle = currentTableView?.style {
            tableView = SettingsTableView(frame: aFrame, style: aStyle)
        }
        title = "Supported iCade Controllers"
#else
        splitViewController?.title = "Supported iCade Controllers"
        tableView.backgroundColor = UIColor.clear
        tableView.backgroundView = nil
#endif
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return iCadeControllerSetting.settingCount.rawValue
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Your controller must be paired with your device in order to work"
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")

        if indexPath.row == PVSettingsModel.shared.myiCadeControllerSetting.rawValue {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        cell.textLabel?.text = iCadeControllerSettingToString((iCadeControllerSetting(rawValue: indexPath.row))!)

#if os(iOS)
        cell.textLabel?.textColor = Theme.currentTheme.settingsCellText
#endif
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        if let aRow = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: aRow, animated: true)
        }
        PVSettingsModel.shared.myiCadeControllerSetting = iCadeControllerSetting(rawValue: indexPath.row)!
        PVControllerManager.shared.resetICadeController()
        navigationController?.popViewController(animated: true)
    }
}
