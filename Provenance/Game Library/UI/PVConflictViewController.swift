//  Converted to Swift 4 by Swiftify v4.1.6632 - https://objectivec2swift.com/
//
//  PVConflictViewController.swift
//  Provenance
//
//  Created by James Addyman on 17/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import UIKit
import RxSwift
import RxDataSources

final class PVConflictViewController: UITableViewController {
    let conflictsController: ConflictsController
    private let disposeBag = DisposeBag()

    init(conflictsController: ConflictsController) {
        self.conflictsController = conflictsController
        super.init(style: .plain)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum Row {
        case conflict(ConflictsController.Conflict)
        case empty(title: String)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        #if os(tvOS)
            splitViewController?.title = "Solve Conflicts"
        #else
            let currentTableview = tableView!
            tableView = SettingsTableView(frame: currentTableview.frame, style: currentTableview.style)

            title = "Solve Conflicts"
            tableView.separatorColor = UIColor.clear
        #endif

        let cellIdentifier = "Cell"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

        let rows = conflictsController.conflicts
            .map({ conflicts -> [Row] in
                if conflicts.isEmpty {
                    return [.empty(title: ""), .empty(title: ""), .empty(title: "No Conflicts...")]
                } else {
                    return conflicts.map { .conflict($0) }
                }
            })

        rows.bind(to: tableView.rx.items(cellIdentifier: cellIdentifier, cellType: UITableViewCell.self)) { _, row, cell in
            switch row {
            case .conflict(let conflict):
                cell.textLabel?.text = conflict.path.deletingPathExtension().lastPathComponent
                cell.accessoryType = .disclosureIndicator
            case .empty(let title):
                cell.textLabel?.text = title
                cell.textLabel?.textAlignment = .center
                cell.accessoryType = .none
            }

            #if os(iOS)
                cell.textLabel?.textColor = Theme.currentTheme.settingsCellText
            #endif
        }
        .disposed(by: disposeBag)

        tableView.rx.itemSelected
            .do(onNext: { self.tableView.deselectRow(at: $0, animated: true) })
            .compactMap({ indexPath -> (ConflictsController.Conflict, IndexPath)? in
                let row: Row = try self.tableView.rx.model(at: indexPath)
                switch row {
                case .conflict(let conflict):
                    return (conflict, indexPath)
                case .empty:
                    return nil
                }
            })
            .bind(onNext: { conflict, indexPath in
                let alertController = UIAlertController(title: "Choose a System", message: nil, preferredStyle: .actionSheet)
                alertController.popoverPresentationController?.sourceView = self.view
                alertController.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
                conflict.candidates.forEach { system in
                    alertController.addAction(.init(title: system.name, style: .default, handler: { _ in
                        self.conflictsController.resolveConflicts(withSolutions: [conflict.path: system])
                    }))
                }

                alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                self.present(alertController, animated: true) { () -> Void in }
            })
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if navigationController == nil || navigationController!.viewControllers.count <= 1 {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissMe))
        }
    }

    @objc func dismissMe() {
        dismiss(animated: true) { () -> Void in }
    }

    #if os(tvOS)
        override func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
            let row: Row = try! tableView.rx.model(at: indexPath)
            switch row {
            case .conflict:
                return true
            case .empty:
                return false
            }
        }
    #endif
}
