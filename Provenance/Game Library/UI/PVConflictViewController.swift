//  Converted to Swift 4 by Swiftify v4.1.6632 - https://objectivec2swift.com/
//
//  PVConflictViewController.swift
//  Provenance
//
//  Created by James Addyman on 17/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

import UIKit

class PVConflictViewController: UITableViewController {
    var gameImporter: PVGameImporter?
    var conflictedFiles: [URL] = [URL]()

    init(gameImporter: PVGameImporter) {
        super.init(style: .plain)

        self.gameImporter = gameImporter
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
#if os(tvOS)
        splitViewController?.title = "Solve Conflicts"
#else
        let currentTableview = self.tableView!
        self.tableView = SettingsTableView(frame: currentTableview.frame, style: currentTableview.style)

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
        dismiss(animated: true) {() -> Void in }
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

	lazy var documentsPath : URL = PVEmulatorConfiguration.documentsPath
	lazy var conflictsPath : URL = PVEmulatorConfiguration.documentsPath.appendingPathComponent("conflicts", isDirectory: true)

#if TARGET_OS_TV
    override func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        if conflictedFiles.count == 0 {
            if indexPath.row == 2 {
                return true
            }
            return false
        }
        return true
    }

#endif
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if conflictedFiles.count != 0 {
            return conflictedFiles.count
        }
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell : UITableViewCell

        if conflictedFiles.isEmpty {
            cell = self.tableView.dequeueReusableCell(withIdentifier: "EmptyCell") ??  UITableViewCell(style: .default, reuseIdentifier: "EmptyCell")
            cell.textLabel?.textAlignment = .center
            if indexPath.row == 0 || indexPath.row == 1 {
                cell.textLabel?.text = ""
            } else {
                cell.textLabel?.text = "No Conflicts..."
			}
        } else {
        	cell = self.tableView.dequeueReusableCell(withIdentifier: "Cell") ??  UITableViewCell(style: .default, reuseIdentifier: "Cell")

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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let aRow = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: aRow, animated: true)
        }

        if conflictedFiles.isEmpty {
            return
        }

        let path = conflictedFiles[indexPath.row]
        let alertController = UIAlertController(title: "Choose a System", message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.sourceView = view
        alertController.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)

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
			alertController.addAction(UIAlertAction(title: name, style: .default, handler: {(_ action: UIAlertAction) -> Void in
				self.gameImporter?.resolveConflicts(withSolutions: [path: system])
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
        present(alertController, animated: true) {() -> Void in }
    }
}
