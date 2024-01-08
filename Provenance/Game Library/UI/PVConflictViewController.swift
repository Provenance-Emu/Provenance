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
        title = "Solve Conflicts"
        #if !os(tvOS)
            let currentTableview = tableView!
            tableView = UITableView(frame: currentTableview.frame, style: currentTableview.style)
            tableView.separatorColor = UIColor.clear
        #endif

		tableView.delegate = nil
		tableView.dataSource = nil

        let cellIdentifier = "Cell"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

        let rows = conflictsController.conflicts
            .map({ conflicts -> [Row] in
                if conflicts.isEmpty {
                    return [.empty(title: "No Conflicts…")]
                } else {
                    return conflicts.map { .conflict($0) }
                }
            })

        rows.bind(to: tableView.rx.items(cellIdentifier: cellIdentifier, cellType: UITableViewCell.self)) { _, row, cell in
            switch row {
            case .conflict(let conflict):
                cell.editingAccessoryType = .checkmark
                cell.textLabel?.text = conflict.path    .lastPathComponent
                cell.accessoryType = .disclosureIndicator
            case .empty(let title):
                cell.textLabel?.text = title
                cell.textLabel?.textAlignment = .center
                cell.accessoryType = .none
                cell.isUserInteractionEnabled = false
            }
        }
        .disposed(by: disposeBag)

        tableView.rx.itemDeleted
            .do(onNext: {
                self.tableView.deselectRow(at: $0, animated: true)
            })
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
                    self.conflictsController.deleteConflict(path: conflict.path)
                    self.tableView.reloadData()
                })
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
                let showsUnsupportedSystems = PVSettingsModel.shared.debugOptions.unsupportedCores
                let alertController = UIAlertController(title: "Choose a System", message: nil, preferredStyle: .actionSheet)
                alertController.popoverPresentationController?.sourceView = self.view
                alertController.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
                conflict.candidates
                    .filter { $0.supported || showsUnsupportedSystems }
                    .sorted(by: { sys1,sys2 in sys1.identifier < sys2.identifier })
                    .forEach { system in
                        alertController.addAction(.init(title: system.name, style: .default, handler: { _ in
                            self.conflictsController.resolveConflicts(withSolutions: [conflict.path: system])
                        }))
                    }
                alertController.addAction(.init(title: NSLocalizedString("Delete", comment: "Delete file"), style: .destructive, handler: { _ in
                    self.conflictsController.deleteConflict(path: conflict.path)
                }))
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
                self.present(alertController, animated: true) { () -> Void in
                    self.tableView.reloadData()
                }
            })
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        #if !os(tvOS)
        if navigationController == nil || navigationController!.viewControllers.count <= 1 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(showEditing))
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissMe))
        }
        #endif
    }

    @objc func dismissMe() {
        dismiss(animated: true) { () -> Void in }
    }
}

extension PVConflictViewController {

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    @objc private func toggleEditing() {
        tableView.setEditing(!tableView.isEditing, animated: true) // Set opposite value of current editing status
        navigationItem.rightBarButtonItem?.title = tableView.isEditing ? "Done" : "Edit" // Set title depending on the editing status
    }

    @objc func showEditing(sender: UIBarButtonItem) {
       if self.tableView.isEditing {
           self.tableView.isEditing = false
           self.navigationItem.rightBarButtonItem?.title = "Done"
       } else {
           self.tableView.isEditing = true
           self.navigationItem.rightBarButtonItem?.title = "Edit"
       }
   }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        // Toggle table view editing.
         tableView.setEditing(editing, animated: true)
    }
}
