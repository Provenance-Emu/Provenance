//
//  CoreOptionsViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/13/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

class CoreOptionsViewController : UITableViewController {
    let core : CoreOptional.Type
    init(withCore core : CoreOptional.Type) {
        self.core = core
        super.init(style: .grouped)
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return groups.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups[section].options.count
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return groups.map { return $0.title }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        let group = groups[indexPath.section]
        let option = group.options[indexPath.row]

        cell.textLabel?.text = option.key

        return cell
    }

}
