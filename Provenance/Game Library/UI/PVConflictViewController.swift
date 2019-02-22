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

final class PVConflictViewController: UITableViewController {
    var gameImporter: GameImporter?
    var conflictedFiles: [URL] = [URL]()

    init(gameImporter: GameImporter) {
        super.init(style: .plain)

        self.gameImporter = gameImporter
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        #if os(tvOS)
            splitViewController?.title = "Solve Conflicts"
        #else
            let currentTableview = tableView!
            tableView = SettingsTableView(frame: currentTableview.frame, style: currentTableview.style)

            title = "Solve Conflicts"
            if !conflictedFiles.isEmpty {
                tableView.separatorColor = UIColor.clear
            }
        #endif
        updateConflictedFiles()
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

    func updateConflictedFiles() {
        guard let filesInConflictsFolder = gameImporter?.conflictedFiles else {
            conflictedFiles = [URL]()
            return
        }

        var tempConflictedFiles = [URL]()
        for file: URL in filesInConflictsFolder {
            let ext: String = file.pathExtension.lowercased()
            if let systems = PVEmulatorConfiguration.systemIdentifiers(forFileExtension: ext), systems.count > 1 {
                tempConflictedFiles.append(file)
            }
        }

        conflictedFiles = tempConflictedFiles
    }

    lazy var documentsPath: URL = PVEmulatorConfiguration.documentsPath
    lazy var conflictsPath: URL = PVEmulatorConfiguration.documentsPath.appendingPathComponent("conflicts", isDirectory: true)

    #if TARGET_OS_TV
        override func tableView(_: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
            if conflictedFiles.isEmpty {
                if indexPath.row == 2 {
                    return true
                }
                return false
            }
            return true
        }

    #endif
    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        if !conflictedFiles.isEmpty {
            return conflictedFiles.count
        }
        return 3
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell

        if conflictedFiles.isEmpty {
            cell = tableView.dequeueReusableCell(withIdentifier: "EmptyCell") ?? UITableViewCell(style: .default, reuseIdentifier: "EmptyCell")
            cell.textLabel?.textAlignment = .center
            if indexPath.row == 0 || indexPath.row == 1 {
                cell.textLabel?.text = ""
            } else {
                cell.textLabel?.text = "No Conflicts..."
            }
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")

            let file = conflictedFiles[indexPath.row]
            let name: String = file.deletingPathExtension().lastPathComponent
            cell.textLabel?.text = name
            cell.accessoryType = .disclosureIndicator
        }

        #if os(iOS)
            cell.textLabel?.textColor = Theme.currentTheme.settingsCellText
        #endif
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let aRow = self.tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: aRow, animated: true)
        }

        if conflictedFiles.isEmpty {
            return
        }

        let path = conflictedFiles[indexPath.row]
        let alertController = UIAlertController(title: "Choose a System", message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.sourceView = view
        alertController.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)

        // This should be a better query, testing - jm
        //		PVSystem.all.filter("supportedExtensions CONTAINS[cd] %@",  path.pathExtension ).forEach { system in
        //			let name: String = system.name
        //			alertController.addAction(UIAlertAction(title: name, style: .default, handler: {(_ action: UIAlertAction) -> Void in
        //				self.gameImporter?.resolveConflicts(withSolutions: [path: system])
        //				// This update crashes since we remove for me on aTV.
        //				//                [self.tableView beginUpdates];
        //				//                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
        //				self.updateConflictedFiles()
        //				self.tableView.reloadData()
        //				//                [self.tableView endUpdates];
        //			}))
        //		}

        PVSystem.all.filter({ $0.supportedExtensions.contains(path.pathExtension) }).forEach { system in
            let name: String = system.name
            alertController.addAction(UIAlertAction(title: name, style: .default, handler: { (_: UIAlertAction) -> Void in
                self.gameImporter?.resolveConflicts(withSolutions: [path: system.asDomain()])
                // This update crashes since we remove for me on aTV.
                //                [self.tableView beginUpdates];
                //                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
                self.updateConflictedFiles()
                self.tableView.reloadData()
                //                [self.tableView endUpdates];
            }))
        }

//        PVSystem.all.forEach { system in
//            if system.supportedExtensions.contains(path.pathExtension) {
//                let name: String = system.name
//                alertController.addAction(UIAlertAction(title: name, style: .default, handler: {(_ action: UIAlertAction) -> Void in
//                    self.gameImporter?.resolveConflicts(withSolutions: [path: system])
//                    // This update crashes since we remove for me on aTV.
//                    //                [self.tableView beginUpdates];
//                    //                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
//                    self.updateConflictedFiles()
//                    self.tableView.reloadData()
//                    //                [self.tableView endUpdates];
//                }))
//            }
//        }

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alertController, animated: true) { () -> Void in }
    }
}
