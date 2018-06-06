//
//  PVSaveStateInfoViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 4/1/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit
import RealmSwift

class PVSaveStateInfoViewController: UIViewController, GameLaunchingViewController {
	var mustRefreshDataSource: Bool = false

	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var nameLabel: UILabel!
	@IBOutlet weak var systemLabel: UILabel!
	@IBOutlet weak var coreLabel: UILabel!
	@IBOutlet weak var coreVersionLabel: UILabel!
	@IBOutlet weak var createdLabel: UILabel!
	@IBOutlet weak var lastPlayedLabel: UILabel!
	@IBOutlet weak var autosaveLabel: UILabel!

	@IBOutlet weak var playBarButtonItem: UIBarButtonItem!

	var saveState : PVSaveState? {
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

	private static let dateFormatter : DateFormatter = {
		let df = DateFormatter()
		df.dateStyle = .short
		return df
	}()

	private static let timeFormatter : DateFormatter = {
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

		if let image = saveState.image {
			imageView.image = UIImage(contentsOfFile: image.url.path)
		} else {
			imageView.image = nil
		}

		nameLabel.text = saveState.game.title
		systemLabel.text = saveState.game.system.name
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
		play(sender)
	}
	/*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

	func play(_ sender: Any) {
		guard let saveState = self.saveState else {
			self.presentError("No save state instance")
			return
		}

		if let libVC = (self.presentingViewController ?? self) as? GameLaunchingViewController {
			libVC.load(self.saveState!.game, sender: sender, core: nil, saveState: saveState)
		}
	}

	var token: NotificationToken?
	func registerForChange() {
		token?.invalidate()
		token = saveState?.observe({ (change) in
			switch change {
			case .change(let properties):
				if !properties.isEmpty, self.isViewLoaded {
					DispatchQueue.main.async {
						self.updateLabels()
					}
				}
			case .error(let error):
				ELOG("An error occurred: \(error)")
			case .deleted:
				print("The object was deleted.")
			}
		})
	}
}

@available(iOS 9.0, *)
extension PVSaveStateInfoViewController {

	// Buttons that shw up under thie VC when it's in a push/pop preview display mode
	override var previewActionItems: [UIPreviewActionItem] {
		let playAction = UIPreviewAction(title: "Play", style: .default) { [unowned self] (action, viewController) in
			self.play(self.view)
		}

		let deleteAction = UIPreviewAction(title: "Delete", style: .destructive) { [unowned self] (action, viewController) in
			let alert = UIAlertController(title: "Delete save state", message: "Are you sure?", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: {(_ action: UIAlertAction) -> Void in
				if let saveState = self.saveState {
					do {
						try PVSaveState.delete(saveState)
					} catch {
						self.presentError("Error deleting save state: " + error.localizedDescription)
					}
				} else {
					ELOG("Save state var was nil, can't delete")
				}
			}))
			alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))

			(UIApplication.shared.delegate?.window??.rootViewController ?? self).present(alert, animated: true)
		}

		return [playAction, deleteAction]
	}
}
