//
//  SystemsSettingsTableViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/7/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import PVLibrary
import RealmSwift
import UIKit

final class SystemsSettingsTableViewController: QuickTableViewController {
    var systemsToken: NotificationToken?

    func generateViewModels() {
        let systems = RomDatabase.sharedInstance.all(PVSystem.self).sorted(byKeyPath: "identifier")
        let systemsModels = systems.map { SystemOverviewViewModel(withSystem: $0) }

        tableContents = systemsModels
            .filter {
                !$0.cores.isEmpty
            }
            .map { systemModel in
            var rows = [Row & RowStyle]()
            rows.append(
                NavigationRow(text: "Games", detailText: .value2("\(systemModel.gameCount)"))
            )

            // CORES
            //			if systemModel.cores.count < 2 {
            let coreNames = systemModel.cores.map { $0.project.name }.joined(separator: ",")
            rows.append(
                NavigationRow(text: "Cores", detailText: .value2(coreNames))
            )
            //			} else {
            //				let preferredCore = systemModel.preferredCore
            //				rows.append(
            //					RadioSection(text: "Cores", options:
            //						systemModel.cores.map { core in
            //							let selected = preferredCore != nil && core == preferredCore!
            //							return OptionRow(text: core.project.name, isSelected: selected, action: didSelectCore(systemIdentifier: core.identifier))
            //						}
            //					)
            //			}

            // BIOSES
                if let bioses = systemModel.bioses, !bioses.isEmpty {
                    let biosesHeader = NavigationRow(
                        text: "BIOSES",
                        detailText: .none,
                        icon: nil,
                        customization: { cell, _ in
#if os(iOS)
                            let bgView = UIView()
                            bgView.backgroundColor = .systemBackground.withAlphaComponent(0.9)
                            cell.backgroundView = bgView
#endif
                        }, action: nil)

                    rows.append(biosesHeader)
                    bioses.forEach { bios in
                    let subtitle = "\(bios.expectedMD5.uppercased()) : \(bios.expectedSize) bytes"

                    let biosRow = NavigationRow(
                        text: bios.descriptionText,
                        detailText: .subtitle(subtitle),
                        icon: nil,
                        customization: { cell, _ in

#if os(iOS)
                            var backgroundColor: UIColor? = .systemBackground
#else
                            var backgroundColor: UIColor? = UIColor.clear
#endif

                            var accessoryType: UITableViewCell.AccessoryType = .none

                            let biosStatus = (bios as! BIOSStatusProvider).status

                            switch biosStatus.state {
                            case .match:
                                accessoryType = .checkmark
                            case .missing:
                                accessoryType = .none
                                backgroundColor = biosStatus.required ? UIColor(hex: "#700") : UIColor(hex: "#77404C")
                            case let .mismatch(mismatches):
                                let subTitleText = mismatches.map { mismatch -> String in
                                    switch mismatch {
                                    case .filename(let expected, _):
                                        return "Filename != \(expected)"
                                    case .md5(let expected, _):
                                        return "MD5 != \(expected)"
                                    case .size(let expected, _):
                                        return "SIZE != \(expected)"
                                    }
                                }.joined(separator: ",")
                                cell.detailTextLabel?.text = subTitleText
                                backgroundColor = UIColor.systemRed.withAlphaComponent(0.5)
                            }

                            cell.accessoryType = accessoryType
                            cell.backgroundView = UIView()
                            cell.backgroundView?.backgroundColor = backgroundColor
                        },
                        action: { _ in
#if os(iOS)
                            UIPasteboard.general.string = bios.expectedMD5.uppercased()
                            let alert = UIAlertController(title: nil, message: "MD5 copied to clipboard.", preferredStyle: .alert)
                            self.present(alert, animated: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                                alert.dismiss(animated: true, completion: nil)
                            })
#endif
                        })
                        rows.append(biosRow)
                    }
            }
            return Section(title: systemModel.title,
                           rows: rows,
                           footer: nil)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        #if os(iOS)
            tableView.separatorStyle = .singleLine
        #else
            tableView.backgroundColor = UIColor.clear
            splitViewController?.title = "Systems"
        #endif

        systemsToken = RomDatabase.sharedInstance.realm.objects(PVSystem.self).observe { _ in
            self.generateViewModels()
            self.tableView.reloadData()
        }
    }

    deinit {
        systemsToken?.invalidate()
    }

    //	private func didSelectCore(identifier: String) -> (Row) -> Void {
    //		return { [weak self] row in
    //			// ...
    //		}
    //	}
}
