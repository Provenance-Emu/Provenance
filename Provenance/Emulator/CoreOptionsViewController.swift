//
//  CoreOptionsViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/13/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

final class CoreOptionsViewController: QuickTableViewController {
    let core: CoreOptional.Type

    init(withCore core: CoreOptional.Type) {
        self.core = core
        super.init(nibName: nil, bundle: nil)
    }

    struct TableGroup {
        let title: String
        let options: [CoreOption]
    }

    lazy var groups: [TableGroup] = {
        var rootOptions = [CoreOption]()

        var groups = core.options.compactMap({ (option) -> TableGroup? in
            switch option {
            case let .group(display, subOptions):
                return TableGroup(title: display.title, options: subOptions)
            default:
                rootOptions.append(option)
                return nil
            }
        })

        if !rootOptions.isEmpty {
            groups.insert(TableGroup(title: "", options: rootOptions), at: 0)
        }

        return groups
    }()

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        generateTableViewViewModels()
        tableView.reloadData()
    }

    func generateTableViewViewModels() {
        #if os(tvOS)
            self.tableView.backgroundColor = .black
            self.tableView.mask = nil
        #endif

		let sections: [Section] = sections(forGroups: self.groups)
        tableContents = sections
    }

	func sections(forGroups groups: [TableGroup]) -> [Section] {
		typealias TableRow = Row & RowStyle

		let sections: [Section] = groups.map {
			let rows: [TableRow] = $0.options.enumerated().map { (rowIndex, option) in
				switch option {
				case let .bool(display, defaultValue):
					let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
					return SwitchRow<PVSwitchCell>(text: display.title, detailText: detailText, switchValue: core.valueForOption(Bool.self, option.key) ?? defaultValue, action: { _ in
						let value = self.core.valueForOption(Bool.self, option.key) ?? defaultValue
						self.core.setValue(!value, forOption: option)
					})
				case let .multi(display, values), let .enumeration(display, values: values):
					let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
					return NavigationRow<SystemSettingsCell>(text: display.title,
															 detailText: detailText,
															 icon: nil,
															 customization: { _, _ in
															 },
															 action: { _ in
																 let currentSelection: String? = self.core.valueForOption(String.self, option.key) ?? option.defaultValue as? String
																 let actionController = UIAlertController(title: display.title, message: nil, preferredStyle: .actionSheet)

																 if let popoverPresentationController = actionController.popoverPresentationController {
																	let cellRect = self.tableView.rectForRow(at: IndexPath(row: rowIndex, section: 0))
																	popoverPresentationController.sourceView = self.tableView
																	popoverPresentationController.sourceRect = cellRect
																 }

																 values.forEach { value in
																	 var title = value.title
																	 if currentSelection == value.title {
																		 title += " ✔︎"
																	 }
																	 let action = UIAlertAction(title: title, style: .default, handler: { _ in
																		 self.core.setValue(value.title, forOption: option)
																	 })
																	 actionController.addAction(action)
																 }
																 actionController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
																 self.present(actionController, animated: true)

																 if let indexPath = self.tableView.indexPathForSelectedRow {
																	 self.tableView.deselectRow(at: indexPath, animated: false)
																 }
					})
				case let .range(display, range: range, defaultValue: defaultValue):
					let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
					return NavigationRow<SystemSettingsCell>(text: display.title,
															 detailText: detailText,
															 icon: nil,
															 customization: { _, _ in
															 },
															 action: { _ in
					})
				case let .rangef(display, range: range, defaultValue: defaultValue):
					let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
					return NavigationRow<SystemSettingsCell>(text: display.title,
															 detailText: detailText,
															 icon: nil,
															 customization: { _, _ in
															 },
															 action: { _ in
					})
				case .string:
					fatalError("Unfinished feature")
				case let .group(display, subOptions: subOptions):
					let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
//					return self.sections(forGroups: subOptions)
					return NavigationRow<SystemSettingsCell>(text: display.title,
															 detailText: detailText,
															 icon: nil,
															 customization: { _, _ in
															 },
															 action: { _ in
					})
				default:
					fatalError("Unfinished feature")
				}
			}
			return Section(title: $0.title, rows: rows)
		}
		return sections
	}
}
