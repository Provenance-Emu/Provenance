//
//  SystemsSettingsTableViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/7/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import UIKit
import RealmSwift
import PVLibrary

import QuickTableViewController

private struct SystemOverviewViewModel {
	let title : String
	let identifier : String
	let gameCount : Int
	let cores : [Core]
	let preferredCore : Core?
	let bioses : [BIOS]?
}

extension SystemOverviewViewModel {
	init(withSystem system : System) {
		title = system.name
		identifier = system.identifier
		gameCount = system.gameStructs.count
		cores = system.coreStructs
		bioses = system.BIOSes
		preferredCore = system.userPreferredCore
	}
}

public class SystemSettingsCell : UITableViewCell {
    public static let identifier : String = String(describing: self)

	public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		sytle()
	}

	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		sytle()
	}

	func sytle() {
		let bg = UIView(frame: bounds)
		bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		#if os(iOS)
		bg.backgroundColor = Theme.currentTheme.settingsCellBackground
		self.textLabel?.textColor = Theme.currentTheme.settingsCellText
		self.detailTextLabel?.textColor = Theme.currentTheme.defaultTintColor
		#else
		bg.backgroundColor = UIColor.init(white: 0.9, alpha: 0.9)
		#endif
		self.backgroundView = bg
	}
}

public class SystemSettingsHeaderCell : SystemSettingsCell {
	override func sytle() {
		super.sytle()
		#if os(iOS)
		self.backgroundView?.backgroundColor = Theme.currentTheme.settingsHeaderBackground
		self.textLabel?.textColor = Theme.currentTheme.settingsHeaderText
		self.detailTextLabel?.textColor = Theme.currentTheme.settingsHeaderText
		#endif
		self.textLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
	}
}

class SystemsSettingsTableViewController: QuickTableViewController {

    var systemsToken: NotificationToken?

    func generateViewModels() {
        let realm  = try! Realm()
        let systems = realm.objects(PVSystem.self).sorted(byKeyPath: "name")
        let systemsModels = systems.map { SystemOverviewViewModel(withSystem: System(with: $0)) }

		tableContents = systemsModels.map { systemModel in
			var rows = [Row & RowStyle]()
			rows.append(
				NavigationRow<SystemSettingsCell>(title: "Games", subtitle: .rightAligned("\(systemModel.gameCount)"))
			)

			// CORES
//			if systemModel.cores.count < 2 {
			if !systemModel.cores.isEmpty {
				let coreNames = systemModel.cores.map {$0.project.name}.joined(separator: ",")
				rows.append(
					NavigationRow<SystemSettingsCell>(title: "Cores", subtitle: .rightAligned(coreNames))
				)
			}
//			} else {
//				let preferredCore = systemModel.preferredCore
//				rows.append(
//					RadioSection(title: "Cores", options:
//						systemModel.cores.map { core in
//							let selected = preferredCore != nil && core == preferredCore!
//							return OptionRow(title: core.project.name, isSelected: selected, action: didSelectCore(systemIdentifier: core.identifier))
//						}
//					)
//			}

			// BIOSES
			if let bioses = systemModel.bioses, !bioses.isEmpty {
				let biosesHeader = NavigationRow<SystemSettingsHeaderCell>(title: "BIOSES",
																		   subtitle: .none,
																		   icon: nil,
																		   customization:
					{ (cell, rowStyle) in
						#if os(iOS)
						let bgView = UIView()
						bgView.backgroundColor = Theme.currentTheme.settingsCellBackground!.withAlphaComponent(0.9)
						cell.backgroundView = bgView
						#endif
				}, action: nil)

				rows.append(biosesHeader)
				bioses.forEach { bios in
					let subtitle = "\(bios.expectedMD5.uppercased()) : \(bios.expectedSize) bytes"

					let biosRow = NavigationRow<SystemSettingsCell>(title: bios.descriptionText,
																	subtitle: .belowTitle(subtitle),
																	icon: nil,
																	customization:
						{ (cell, row) in

							#if os(iOS)
							var backgroundColor : UIColor? = Theme.currentTheme.settingsCellBackground
							#else
							var backgroundColor : UIColor? = UIColor.init(white: 0.9, alpha: 0.9)
							#endif

							var accessoryType : UITableViewCellAccessoryType = .none

							switch bios.status.state {
							case .match:
								accessoryType = .checkmark
							case .missing:
								accessoryType = .none
								backgroundColor = bios.status.required ? UIColor(hex: "#700") : UIColor(hex: "#77404C")
							case .mismatch(let mismatches):
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
								backgroundColor = UIColor(hex: "#77404C")
							}

							cell.accessoryType = accessoryType
							cell.backgroundView = UIView()
							cell.backgroundView?.backgroundColor = backgroundColor
					},
																	action:
						{ row in
							UIPasteboard.general.string = bios.expectedMD5.uppercased()
							let alert = UIAlertController(title: nil, message: "MD5 copied to clipboard", preferredStyle: .alert)
							self.present(alert, animated: true)
							DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
								alert.dismiss(animated: true, completion: nil)
							})
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
		self.tableView.backgroundColor = Theme.currentTheme.settingsHeaderBackground
		self.tableView.separatorStyle = .singleLine
		#endif

        let realm  = try! Realm()
        systemsToken = realm.objects(PVSystem.self).observe { (systems) in
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
