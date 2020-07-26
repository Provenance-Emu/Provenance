//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PViCadeControllerViewController.swift
//  Provenance
//
//  Created by James Addyman on 17/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

import PVSupport
import UIKit

final class PViCadeControllerViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        #if os(tvOS)
            tableView.backgroundColor = UIColor.clear
            tableView.backgroundView = nil
        #endif
    }

    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return iCadeControllerSetting.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "iCadeCell") ?? UITableViewCell(style: .default, reuseIdentifier: "iCadeCell")

        if indexPath.row == PVSettingsModel.shared.myiCadeControllerSetting.rawValue {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        cell.textLabel?.text = iCadeControllerSetting(rawValue: indexPath.row)?.description ?? "nil"

        #if os(iOS)
            cell.textLabel?.textColor = Theme.currentTheme.settingsCellText
        #endif

        return cell
    }

    override func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        return "Supported iCade Controllers"
    }

    override func tableView(_: UITableView, titleForFooterInSection _: Int) -> String? {
        return "Controllers must be paired with device."
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        if let aRow = self.tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: aRow, animated: true)
        }
        PVSettingsModel.shared.myiCadeControllerSetting = iCadeControllerSetting(rawValue: indexPath.row)!
        PVControllerManager.shared.resetICadeController()
        navigationController?.popViewController(animated: true)
    }
}
