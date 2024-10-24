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
import Observation
#if canImport(UIKit)
import UIKit
typealias BaseContoller = UITableViewController
#elseif canImport(AppKit)
import AppKit
typealias BaseContoller = NSTableViewController
#endif
import PVSettings

final class PVConflictViewController: BaseContoller {
    let conflictsController: PVGameLibraryUpdatesController
    @Published private var rows: [Row] = []

    init(conflictsController: PVGameLibraryUpdatesController) {
        self.conflictsController = conflictsController
        super.init(style: .plain)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum Row {
        case conflict(ConflictsController.ConflictItem)
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

        tableView.delegate = self
        tableView.dataSource = self

        let cellIdentifier = "Cell"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

        setupObservers()
    }

    private func setupObservers() {
        Task { @MainActor in
            for await conflicts in conflictsController.$conflicts.values {
                if conflicts.isEmpty {
                    self.rows = [.empty(title: "No Conflicts…")]
                } else {
                    self.rows = conflicts.map { .conflict($0) }
                }
                self.tableView.reloadData()
            }
        }
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

extension PVConflictViewController { // : UITableViewDataSource, UITableViewDelegate {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let row = rows[indexPath.row]
        switch row {
        case .conflict(let conflict):
            cell.editingAccessoryType = .checkmark
            cell.textLabel?.text = conflict.path.lastPathComponent
            cell.accessoryType = .disclosureIndicator
            cell.isUserInteractionEnabled = true
        case .empty(let title):
            cell.textLabel?.text = title
            cell.textLabel?.textAlignment = .center
            cell.accessoryType = .none
            cell.isUserInteractionEnabled = false
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if case .conflict(let conflict) = rows[indexPath.row] {
                Task {
                    await conflictsController.deleteConflict(path: conflict.path)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if case .conflict(let conflict) = rows[indexPath.row] {
            showSystemSelectionAlert(for: conflict, at: indexPath)
        }
    }

    private func showSystemSelectionAlert(for conflict: ConflictsController.ConflictItem, at indexPath: IndexPath) {
        let showsUnsupportedSystems = Defaults[.unsupportedCores]
        let alertController = UIAlertController(title: "Choose a System", message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.sourceView = self.view
        alertController.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
        conflict.candidates
            .filter { $0.supported || showsUnsupportedSystems }
            .sorted(by: { sys1,sys2 in sys1.identifier < sys2.identifier })
            .forEach { system in
                alertController.addAction(.init(title: system.name, style: .default, handler: { _ in
                    Task {
                        await self.conflictsController.resolveConflicts(withSolutions: [conflict.path: system])
                    }
                }))
            }
        alertController.addAction(.init(title: NSLocalizedString("Delete", comment: "Delete file"), style: .destructive, handler: { _ in
            Task {
                await self.conflictsController.deleteConflict(path: conflict.path)
            }
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
        self.present(alertController, animated: true) { () -> Void in
            self.tableView.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    @objc private func toggleEditing() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        navigationItem.rightBarButtonItem?.title = tableView.isEditing ? "Done" : "Edit"
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
        tableView.setEditing(editing, animated: true)
    }
}
