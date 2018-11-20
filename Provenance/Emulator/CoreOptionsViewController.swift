//
//  CoreOptionsViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/13/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import QuickTableViewController

class CoreOptionsViewController : QuickTableViewController {
    let core : CoreOptional.Type

    init(withCore core : CoreOptional.Type) {
        self.core = core
        super.init(nibName: nil, bundle: nil)
    }

    struct TableGroup {
        let title : String
        let options : [CoreOption]
    }

    lazy var groups : [TableGroup] = {
        var rootOptions = [CoreOption]()

        var groups = core.options.compactMap({ (option) -> TableGroup? in
            switch option {
            case .group(let display, let subOptions):
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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        generateTableViewViewModels()
        tableView.reloadData()
    }

    func generateTableViewViewModels() {
        typealias TableRow = Row & RowStyle

        let sections : [Section] = groups.map {
            let rows : [TableRow] = $0.options.map { option in
                switch option {
                case .bool(let display, let defaultValue):
                    return SwitchRow(title: display.title, switchValue: core.valueForOption(Bool.self, option.key) ?? false, action: { (row) in
                        let value = self.core.valueForOption(Bool.self, option.key) ?? false
                        self.core.setValue(!value, forOption: option)
                    })
                case .multi(let display, let values):
                    let subtitle : Subtitle = display.description != nil ? Subtitle.belowTitle(display.description!) : .none
                    return NavigationRow<SystemSettingsCell>(title: display.title,
                                                             subtitle: subtitle,
                                                             icon: nil,
                                                             customization: { (cell, row) in
                    },
                                                             action: { (row) in
                                                                let currentSelection : String? = self.core.valueForOption(String.self, option.key) ?? option.defaultValue as? String
                                                                let actionController = UIAlertController(title: display.title, message: nil, preferredStyle: .actionSheet)
                                                                values.forEach { value in
                                                                    var title = value.title
                                                                    if currentSelection == value.title {
                                                                        title = title + "✔︎ "
                                                                    }
                                                                    let action = UIAlertAction(title: title, style: .default, handler: { (action) in
                                                                        self.core.setValue(value.title, forOption: option)
                                                                    })
                                                                    actionController.addAction(action)
                                                                }
                                                                actionController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                                                                self.present(actionController, animated: true)
                    })
                case .range(let display, let range, let defaultValue):
                    fatalError("Unfinished feature")
                case .string(let display, let defaultValue):
                    fatalError("Unfinished feature")
                default:
                    fatalError("Unfinished feature")
                }
            }
            return Section(title: $0.title, rows: rows)
        }

        self.tableContents = sections
    }
}
