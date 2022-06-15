//
//  CoreOptionsViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/13/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import UIKit

final class CoreOptionsViewController: QuickTableViewController {
    let core: CoreOptional.Type
    
    let subOptions: [CoreOption]?
    
    init(withCore core: CoreOptional.Type, subOptions: [CoreOption]? = nil) {
        self.core = core
        self.subOptions = subOptions
        super.init(nibName: nil, bundle: nil)
    }

    struct TableGroup {
        let title: String
        let options: [CoreOption]
    }

    lazy var groups: [TableGroup] = {
        var rootOptions = [CoreOption]()
        let options: [CoreOption] = subOptions ?? core.options
        var groups = options.compactMap({ (option) -> TableGroup? in
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

        let sections: [Section] = groups.enumerated().map { sectionIndex, group in
			let rows: [TableRow] = group.options.enumerated().map { (rowIndex, option) in
				switch option {
				case let .bool(display, defaultValue):
					let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
					return SwitchRow<PVSwitchCell>(text: display.title, detailText: detailText, switchValue: core.storedValueForOption(Bool.self, option.key) ?? defaultValue, action: { _ in
						let value = self.core.storedValueForOption(Bool.self, option.key) ?? defaultValue
						self.core.setValue(!value, forOption: option)
					})
				case let .multi(display, values):
					let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
					return NavigationRow<SystemSettingsCell>(text: display.title,
															 detailText: detailText,
															 icon: nil,
															 customization: { _, _ in
															 },
															 action: { _ in
																 let currentSelection: String? = self.core.storedValueForOption(String.self, option.key) ?? option.defaultValue as? String
																 let actionController = UIAlertController(title: display.title, message: nil, preferredStyle: .actionSheet)

																 if let popoverPresentationController = actionController.popoverPresentationController {
																	let cellRect = self.tableView.rectForRow(at: IndexPath(row: rowIndex, section: sectionIndex))
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
                case let .enumeration(display, values: values, defaultValue: defaultValue):
                    let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
                    return NavigationRow<SystemSettingsCell>(text: display.title,
                                                             detailText: detailText,
                                                             icon: nil,
                                                             customization: { _, _ in
                                                             },
                                                             action: { row in
                                                                 let currentSelection: Int = self.core.storedValueForOption(Int.self, option.key) ?? option.defaultValue as? Int ?? defaultValue
                                                                 let actionController = UIAlertController(title: display.title, message: nil, preferredStyle: .actionSheet)

#if !os(tvOS)
                            if #available(iOS 15.0, *), let sheetPresentationController = actionController.sheetPresentationController {
//                                let cellRect = self.tableView.rectForRow(at: IndexPath(row: rowIndex, section: sectionIndex))
                                sheetPresentationController.sourceView = self.tableView
//                                sheetPresentationController.sourceRect = cellRect
                            } else if let popoverPresentationController = actionController.popoverPresentationController {
                                let cellRect = self.tableView.rectForRow(at: IndexPath(row: rowIndex, section: sectionIndex))
                                popoverPresentationController.sourceView = self.tableView
                                popoverPresentationController.sourceRect = cellRect
                             }
                        #else
                        if let popoverPresentationController = actionController.popoverPresentationController {
                            let cellRect = self.tableView.rectForRow(at: IndexPath(row: rowIndex, section: sectionIndex))
                            popoverPresentationController.sourceView = self.tableView
                            popoverPresentationController.sourceRect = cellRect
                         }
                        #endif
                        
                                                                

                                                                 values.forEach { value in
                                                                     var title = value.title
                                                                     if currentSelection == value.value {
                                                                         title += " ✔︎"
                                                                     }
                                                                     let action = UIAlertAction(title: title, style: .default, handler: { _ in
                                                                         self.core.setValue(value.value, forOption: option)
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
                    let value = core.storedValueForOption(Int.self, option.key) ?? defaultValue
                    
                    #if os(tvOS)
                    // TODO: slider on tvOS?
                    return NavigationRow<SystemSettingsCell>(text: "\(display.title): \(value)",
                                                             detailText: detailText,
                                                             icon: nil,
                                                             customization: { _, _ in
                                                             },
                                                             action: { _ in
                    })
                    #else
                    return SliderRow<PVSliderCell>(
                        text: display.title,
                        detailText: detailText,
                        value: Float(value),
                        valueLimits: (min: Float(range.min), max: Float(range.max)),
                        valueImages: (min: nil, max: nil),
                        customization: nil)
                    { _ in
                        let value = self.core.storedValueForOption(Int.self, option.key) ?? defaultValue
                        self.core.setValue(value, forOption: option)
                    }
                    #endif
				case let .rangef(display, range: range, defaultValue: defaultValue):
                    let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
                    let value = core.storedValueForOption(Float.self, option.key) ?? defaultValue
                    #if os(tvOS)
                    // TODO: slider on tvOS?
                    return NavigationRow<SystemSettingsCell>(text: "\(display.title): \(value)",
                                                             detailText: detailText,
                                                             icon: nil,
                                                             customization: { _, _ in
                                                             },
                                                             action: { _ in
                    })
                    #else
                    return SliderRow<PVSliderCell>(
                        text: display.title,
                        detailText: detailText,
                        value: value,
                        valueLimits: (min: range.min, max: range.max),
                        valueImages: (min: nil, max: nil),
                        customization: nil)
                    { _ in
                        let value = self.core.storedValueForOption(Float.self, option.key) ?? defaultValue
                        self.core.setValue(value, forOption: option)
                    }
                    #endif
                case let .string(display, defaultValue: defaultValue):
                    let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
                    let value = core.storedValueForOption(String.self, option.key) ?? defaultValue
                    
                    return NavigationRow<SystemSettingsCell>(text: display.title,
                                                             detailText: detailText,
                                                             icon: nil,
                                                             customization: { cell, _ in
//                        cell.textLabel?.text = value
                                                             },
                                                             action: { cell in
                                                                 let currentValue: String = value // self.core.valueForOption(String.self, option.key) ?? option.defaultValue as? String ?? ""
                                                                 let actionController = UIAlertController(title: display.title, message: nil, preferredStyle: .actionSheet)
                        let cellRect = self.tableView.rectForRow(at: IndexPath(row: rowIndex, section: sectionIndex))

                        let textField = UITextField()
                        textField.text = value
                                                                 if let popoverPresentationController = actionController.popoverPresentationController {
                                                                    popoverPresentationController.sourceView = self.tableView
                                                                    popoverPresentationController.sourceRect = cellRect
                                                                 }

//                                                                 values.forEach { value in
//                                                                     var title = value.title
//                                                                     if currentSelection == value.value {
//                                                                         title += " ✔︎"
//                                                                     }
//                                                                     let action = UIAlertAction(title: title, style: .default, handler: { _ in
//                                                                         self.core.setValue(value.value, forOption: option)
//                                                                     })
//                                                                     actionController.addAction(action)
//                                                                 }
                                                                 actionController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                                                                 self.present(actionController, animated: true)

                                                                 if let indexPath = self.tableView.indexPathForSelectedRow {
                                                                     self.tableView.deselectRow(at: indexPath, animated: false)
                                                                 }
                    })
                case let .group(display, subOptions: subOptions):
                    let detailText: DetailText = display.description != nil ? DetailText.subtitle(display.description!) : .none
                    return NavigationRow<SystemSettingsCell>(text: display.title,
                                                             detailText: detailText,
                                                             icon: nil,
                                                             customization: { _, _ in
                    },
                                                             action:
                                                                { [weak self] row in
                        guard let self = self else { return }
                        let subOptionsVC = CoreOptionsViewController(withCore: self.core, subOptions: subOptions)
                        subOptionsVC.title = row.text
                        self.navigationController?.pushViewController(subOptionsVC, animated: true)
                    })
                @unknown default:
					fatalError("Unfinished feature")
				}
			}
			return Section(title: group.title, rows: rows)
		}
		return sections
	}
}
