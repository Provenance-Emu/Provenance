//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVControllerSelectionViewController.swift
//  Provenance
//
//  Created by James Addyman on 19/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import GameController
import PVUIBase
#if canImport(UIKit)
import UIKit
#endif

final class PVControllerSelectionViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        #if TARGET_OS_TV
            tableView.backgroundColor = UIColor.clear
            tableView.backgroundView = nil
        #endif
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return 8
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "controllerCell")!

        let labelText = "Player \(indexPath.row + 1)"

        cell.textLabel?.text = labelText

        var controller: GCController?
        switch indexPath.row {
        case 0:
            controller = PVControllerManager.shared.player1
        case 1:
            controller = PVControllerManager.shared.player2
        case 2:
            controller = PVControllerManager.shared.player3
        case 3:
            controller = PVControllerManager.shared.player4
        case 4:
            controller = PVControllerManager.shared.player5
        case 5:
            controller = PVControllerManager.shared.player6
        case 6:
            controller = PVControllerManager.shared.player7
        case 7:
            controller = PVControllerManager.shared.player8
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

    override func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        return "Controller Assignments"
    }

    override func tableView(_: UITableView, titleForFooterInSection _: Int) -> String? {
        return "Controllers must be paired with device."
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let player: Int = indexPath.row + 1
        let actionSheet = UIAlertController(title: "Select a controller for Player \(player)", message: "or press a button on your iCade controller.", preferredStyle: .actionSheet)

        #if targetEnvironment(macCatalyst) || os(macOS)
        actionSheet.popoverPresentationController?.sourceView = self.tableView
        actionSheet.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
        #else
        if traitCollection.userInterfaceIdiom == .pad {
            actionSheet.popoverPresentationController?.sourceView = self.tableView
            actionSheet.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
        }
        #endif

        for controller: GCController in PVControllerManager.shared.controllers {
            var title = controller.vendorName ?? ""

            if controller == PVControllerManager.shared.player1 {
                title.append(" (Player 1)")
            } else if controller == PVControllerManager.shared.player2 {
                title.append(" (Player 2)")
            } else if controller == PVControllerManager.shared.player3 {
                title.append(" (Player 3)")
            } else if controller == PVControllerManager.shared.player4 {
                title.append(" (Player 4)")
            } else if controller == PVControllerManager.shared.player5 {
                title.append(" (Player 5)")
            } else if controller == PVControllerManager.shared.player6 {
                title.append(" (Player 6)")
            } else if controller == PVControllerManager.shared.player7 {
                title.append(" (Player 7)")
            } else if controller == PVControllerManager.shared.player8 {
                title.append(" (Player 8)")
            }

            actionSheet.addAction(UIAlertAction(title: title, style: .default, handler: { (_: UIAlertAction) -> Void in
                if indexPath.row == 0 {
                    PVControllerManager.shared.setController(controller, toPlayer: 1)
                } else if indexPath.row == 1 {
                    PVControllerManager.shared.setController(controller, toPlayer: 2)
                } else if indexPath.row == 2 {
                    PVControllerManager.shared.setController(controller, toPlayer: 3)
                } else if indexPath.row == 3 {
                    PVControllerManager.shared.setController(controller, toPlayer: 4)
                } else if indexPath.row == 4 {
                    PVControllerManager.shared.setController(controller, toPlayer: 5)
                } else if indexPath.row == 5 {
                    PVControllerManager.shared.setController(controller, toPlayer: 6)
                } else if indexPath.row == 6 {
                    PVControllerManager.shared.setController(controller, toPlayer: 7)
                } else if indexPath.row == 7 {
                    PVControllerManager.shared.setController(controller, toPlayer: 8)
                }

                DispatchQueue.main.async {
                    let visibleIndex = self.tableView.visibleCells.compactMap { tableView.indexPath(for: $0) }
                    self.tableView.reloadRows(at: visibleIndex, with: .none)
                }
                PVControllerManager.shared.stopListeningForICadeControllers()
            }))
        }

        actionSheet.addAction(UIAlertAction(title: "Not Playing", style: .default, handler: { (_: UIAlertAction) -> Void in
            if indexPath.row == 0 {
                PVControllerManager.shared.setController(nil, toPlayer: 1)
            } else if indexPath.row == 1 {
                PVControllerManager.shared.setController(nil, toPlayer: 2)
            } else if indexPath.row == 2 {
                PVControllerManager.shared.setController(nil, toPlayer: 3)
            } else if indexPath.row == 3 {
                PVControllerManager.shared.setController(nil, toPlayer: 4)
            } else if indexPath.row == 4 {
                PVControllerManager.shared.setController(nil, toPlayer: 5)
            } else if indexPath.row == 5 {
                PVControllerManager.shared.setController(nil, toPlayer: 6)
            } else if indexPath.row == 6 {
                PVControllerManager.shared.setController(nil, toPlayer: 7)
            } else if indexPath.row == 7 {
                PVControllerManager.shared.setController(nil, toPlayer: 8)
            }

            DispatchQueue.main.async {
                let visibleIndex = self.tableView.visibleCells.compactMap { tableView.indexPath(for: $0) }
                self.tableView.reloadRows(at: visibleIndex, with: .none)
            }
            PVControllerManager.shared.stopListeningForICadeControllers()
        }))

        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))

        present(actionSheet, animated: true, completion: { () -> Void in
            PVControllerManager.shared.listenForICadeControllers(window: actionSheet.view.window, preferredPlayer: indexPath.row + 1, completion: { () -> Void in
                actionSheet.dismiss(animated: true) { () -> Void in }
            })
        })
    }
}
