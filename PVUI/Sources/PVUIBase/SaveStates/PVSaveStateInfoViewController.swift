//
//  PVSaveStateInfoViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 4/1/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import RealmSwift
import PVRealm
import PVLogging

#if canImport(UIKit)
import UIKit
#endif

final class PVSaveStateInfoViewController: UIViewController, GameLaunchingViewController {
    var mustRefreshDataSource: Bool = false

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var systemLabel: UILabel!
    @IBOutlet var coreLabel: UILabel!
    @IBOutlet var coreVersionLabel: UILabel!
    @IBOutlet var createdLabel: UILabel!
    @IBOutlet var lastPlayedLabel: UILabel!
    @IBOutlet var autosaveLabel: UILabel!

    @IBOutlet var playBarButtonItem: UIBarButtonItem!

    var saveState: PVSaveState? {
        didSet {
            assert(saveState != nil, "Set a nil game")

            if saveState != oldValue {
                registerForChange()

                if isViewLoaded {
                    updateLabels()
                }
            }
        }
    }

    deinit {
        token?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = playBarButtonItem

        updateLabels()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateLabels()
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let tf = DateFormatter()
        tf.timeStyle = .short
        return tf
    }()

    func updateLabels() {
        guard let saveState = saveState else {
            imageView.image = nil
            nameLabel.text = ""
            systemLabel.text = ""
            coreLabel.text = ""
            coreVersionLabel.text = ""
            createdLabel.text = ""
            lastPlayedLabel.text = ""

            return
        }

        Task {
            if let image = saveState.image, let path = image.url?.path {
                imageView.image = UIImage(contentsOfFile: path)
            } else {
                imageView.image = nil
            }
        }

        nameLabel.text = saveState.game.title
        systemLabel.text = saveState.game.system?.name ?? ""
        coreLabel.text = saveState.core.projectName
        coreVersionLabel.text = saveState.createdWithCoreVersion

        let createdText = "\(PVSaveStateInfoViewController.dateFormatter.string(from: saveState.date)), \(PVSaveStateInfoViewController.timeFormatter.string(from: saveState.date))"
        createdLabel.text = createdText

        title = "\(saveState.game.title) : \(createdText)"

        if let lastOpened = saveState.lastOpened {
            let lastOpenedText = "\(PVSaveStateInfoViewController.dateFormatter.string(from: lastOpened)), \(PVSaveStateInfoViewController.timeFormatter.string(from: lastOpened))"
            print("Last opened \(lastOpenedText)")
            lastPlayedLabel.text = lastOpenedText
        } else {
            lastPlayedLabel.text = "Never"
        }

        autosaveLabel.text = saveState.isAutosave ? "Yes" : "No"
    }

    @IBAction func playButtonTapped(_ sender: Any) {
        Task.detached { [weak self] in
            await self?.play(sender)
        }
    }

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */

    func play(_ sender: Any) async {
        guard let saveState = self.saveState else {
            presentError("No save state instance", source: sender as! UIView)
            return
        }

        if let libVC = (self.presentingViewController ?? self) as? GameLaunchingViewController {
            await libVC.load(self.saveState!.game, sender: sender, core: nil, saveState: saveState)
        }
    }

    var token: NotificationToken?
    func registerForChange() {
        token?.invalidate()
        token = saveState?.observe({ change in
            switch change {
            case let .change(_, properties):
                if !properties.isEmpty, self.isViewLoaded {
                    DispatchQueue.main.async {
                        self.updateLabels()
                    }
                }
            case let .error(error):
                ELOG("An error occurred: \(error)")
            case .deleted:
                print("The object was deleted.")
            }
        })
    }
}

extension PVSaveStateInfoViewController {
    // Buttons that shw up under thie VC when it's in a push/pop preview display mode
    override var previewActionItems: [UIPreviewActionItem] {
        let playAction = UIPreviewAction(title: "Play", style: .default) { [unowned self] _, _ in
            if let view = self.view {
                Task.detached { [weak self] in
                    await self?.play(view)
                }
            } else {
                assertionFailure("Nil view")
            }
        }

        let deleteAction = UIPreviewAction(title: "Delete", style: .destructive) { [unowned self] _, _ in
            let alert = UIAlertController(title: "Delete save state", message: "Are you sure?", preferredStyle: .alert)
            alert.preferredContentSize = CGSize(width: 300, height: 150)
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = UIScreen.main.bounds
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (_: UIAlertAction) -> Void in
                Task { @MainActor in
                    if let saveState = self.saveState {
                        do {
                            try PVSaveState.delete(saveState)
                        } catch {
                            self.presentError("Error deleting save state: " + error.localizedDescription, source: self.view)
                        }
                    } else {
                        ELOG("Save state var was nil, can't delete")
                    }
                }
           }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))

            (UIApplication.shared.delegate?.window??.rootViewController ?? self).present(alert, animated: true)
        }

        return [playAction, deleteAction]
    }
}
