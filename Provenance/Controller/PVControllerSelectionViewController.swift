//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVControllerSelectionViewController.swift
//  Provenance
//
//  Created by James Addyman on 19/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import GameController
import UIKit

class PVControllerSelectionViewController: UITableViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerSelectionViewController.handleReassigned(_:)), name: NSNotification.Name.PVControllerManagerControllerReassigned, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.PVControllerManagerControllerReassigned, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
#if TARGET_OS_TV
        tableView.backgroundColor = UIColor.clear
        tableView.backgroundView = nil
#endif
    }

    @objc func handleReassigned(_ notification: Notification?) {
        tableView.reloadData()
    }

// MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "controllerCell")!

        let labelText = "Player \(indexPath.row + 1)"
        cell.textLabel?.text = labelText

        var controller: GCController? = nil
        switch indexPath.row {
        case 0:
            controller = PVControllerManager.shared.player1
        case 1:
            controller = PVControllerManager.shared.player2
        case 2:
            controller = PVControllerManager.shared.player3
        case 3:
            controller = PVControllerManager.shared.player4
        default:
            controller = nil
        }

        if let controller = controller {
            cell.detailTextLabel?.text = controller.vendorName ?? "No Vendor Name"
        } else {
            cell.detailTextLabel?.text = "None Selected"
        }

        return cell
    }

// MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Controller Assignments"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Controllers must be paired with device."
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let player: Int = indexPath.row + 1
        let actionSheet = UIAlertController(title: "Select a controller for Player \(player)", message: "or press a button on your iCade controller.", preferredStyle: .actionSheet)

        if traitCollection.userInterfaceIdiom == .pad {
            actionSheet.popoverPresentationController?.sourceView = self.tableView
            actionSheet.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
        }

        for controller: GCController in GCController.controllers() {
            var title = controller.vendorName ?? ""

            if controller == PVControllerManager.shared.player1 {
                title.append(" (Player 1")
            } else if controller == PVControllerManager.shared.player2 {
                title.append(" (Player 2")
            } else if controller == PVControllerManager.shared.player3 {
                title.append(" (Player 3")
            } else if controller == PVControllerManager.shared.player4 {
                title.append(" (Player 4")
            }

            actionSheet.addAction(UIAlertAction(title: title, style: .default, handler: {(_ action: UIAlertAction) -> Void in
                if indexPath.row == 0 {
					PVControllerManager.shared.setController(controller, toPlayer: 1)
                } else if indexPath.row == 1 {
					PVControllerManager.shared.setController(controller, toPlayer: 2)
                } else if indexPath.row == 2 {
					PVControllerManager.shared.setController(controller, toPlayer: 3)
                } else if indexPath.row == 3 {
					PVControllerManager.shared.setController(controller, toPlayer: 4)
                }
                self.tableView.reloadData()
                PVControllerManager.shared.stopListeningForICadeControllers()
            }))
        }

        actionSheet.addAction(UIAlertAction(title: "Not Playing", style: .default, handler: {(_ action: UIAlertAction) -> Void in
			if indexPath.row == 0 {
				PVControllerManager.shared.setController(nil, toPlayer: 1)
			} else if indexPath.row == 1 {
				PVControllerManager.shared.setController(nil, toPlayer: 2)
			} else if indexPath.row == 2 {
				PVControllerManager.shared.setController(nil, toPlayer: 3)
			} else if indexPath.row == 3 {
				PVControllerManager.shared.setController(nil, toPlayer: 4)
			}
            self.tableView.reloadData()
            PVControllerManager.shared.stopListeningForICadeControllers()
        }))

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(actionSheet, animated: true, completion: {[unowned self] () -> Void in
			PVControllerManager.shared.listenForICadeControllers(window: actionSheet.view.window, preferredPlayer: indexPath.row + 1, completion: {() -> Void in
                self.tableView.reloadData()
                actionSheet.dismiss(animated: true) {() -> Void in }
            })
        })
    }
}
