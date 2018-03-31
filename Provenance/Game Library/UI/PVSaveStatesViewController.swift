//
//  PVSaveStatesViewController.swift
//  Provenance
//
//  Created by James Addyman on 30/03/2018.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit
import Realm

protocol PVSaveStatesViewControllerDelegate: class {
	func saveStatesViewControllerDone(_ saveStatesViewController: PVSaveStatesViewController)
	func saveStatesViewControllerCreateNewState(_ saveStatesViewController: PVSaveStatesViewController)
	func saveStatesViewController(_ saveStatesViewController: PVSaveStatesViewController, load state: PVSaveState);
}

class PVSaveStatesViewController: UICollectionViewController {
	private let dateFormatter = DateFormatter()
	private let timeFormatter = DateFormatter()
	
	private var autoSaveStatesObserverToken: NotificationToken!
	private var manualSaveStatesObserverToken: NotificationToken!
	
	weak var delegate: PVSaveStatesViewControllerDelegate?
	
	var saveStates: List<PVSaveState>!
	var screenshot: UIImage?
	
	private var autoSaves: Results<PVSaveState>!
	private var manualSaves: Results<PVSaveState>!

	deinit {
		autoSaveStatesObserverToken.invalidate()
		autoSaveStatesObserverToken = nil
		manualSaveStatesObserverToken.invalidate()
		manualSaveStatesObserverToken = nil
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
#if os(iOS)
		title = "Save States"
#endif
		
		dateFormatter.dateStyle = .short
		timeFormatter.timeStyle = .short
		
		autoSaves = saveStates.filter("isAutosave == true").sorted(byKeyPath: "date", ascending: false)
		manualSaves = saveStates.filter("isAutosave == false").sorted(byKeyPath: "date", ascending: false)
		
		autoSaveStatesObserverToken = autoSaves.observe { [unowned self] (changes: RealmCollectionChange) in
			switch changes {
			case .initial(_):
				self.collectionView?.reloadData()
			case .update(_, let deletions, _, _):
				guard deletions.count > 0 else {
					return
				}
				
				let fromItem = { (item: Int) -> IndexPath in
					let section = 0
					return IndexPath(item: item, section: section)
				}
				self.collectionView?.performBatchUpdates({
					self.collectionView?.deleteItems(at: deletions.map(fromItem))
				}, completion: nil)
			case .error(let error):
				ELOG("Error updating save states: \(error.localizedDescription)")
			}
		}
		
		manualSaveStatesObserverToken = manualSaves.observe { [unowned self] (changes: RealmCollectionChange) in
			switch changes {
			case .initial(_):
				self.collectionView?.reloadData()
			case .update(_, let deletions, let insertions, _):
				guard deletions.count > 0 || insertions.count > 0 else {
					return
				}
				let fromItem = { (item: Int) -> IndexPath in
					let section = 1
					return IndexPath(item: item, section: section)
				}
				self.collectionView?.performBatchUpdates({
					self.collectionView?.deleteItems(at: deletions.map(fromItem))
					self.collectionView?.insertItems(at: insertions.map(fromItem))
				}, completion: nil)
			case .error(let error):
				ELOG("Error updating save states: \(error.localizedDescription)")
			}
		}
		
		let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressRecognized(_:)))
		collectionView?.addGestureRecognizer(longPressRecognizer)
    }
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		if let emulatorViewController = presentingViewController as? PVEmulatorViewController {
			emulatorViewController.core.setPauseEmulation(false)
			emulatorViewController.isShowingMenu = false
			emulatorViewController.enableContorllerInput(false)
		}
	}
	
	@objc func longPressRecognized(_ recognizer: UILongPressGestureRecognizer) {
		switch recognizer.state {
		case .began:
			let point: CGPoint = recognizer.location(in: collectionView)
			var maybeIndexPath: IndexPath? = collectionView?.indexPathForItem(at: point)
			
#if os(tvOS)
			if maybeIndexPath == nil, let focusedView = UIScreen.main.focusedView as? UICollectionViewCell {
				maybeIndexPath = collectionView?.indexPath(for: focusedView)
			}
#endif
			guard let indexPath = maybeIndexPath else {
				ELOG("No index path at touch point")
				return
			}
			
			var state: PVSaveState?
			switch indexPath.section {
			case 0:
				state = autoSaves[indexPath.item]
			case 1:
				state = manualSaves[indexPath.item]
			default:
				break
			}
			
			guard let saveState = state else {
				ELOG("No save state at indexPath: \(indexPath)")
				return
			}
			
			let alert = UIAlertController(title: "Delete this save state?", message: nil, preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { action in
				do {
					try FileManager.default.removeItem(at: saveState.file.url)
					if let image = saveState.image {
						try FileManager.default.removeItem(at: image.url)
					}
					let realm = try Realm()
					try realm.write {
						realm.delete(saveState)
					}
				} catch let error {
					ELOG("Error deleting save state: \(error.localizedDescription)")
				}
			})
			alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
			present(alert, animated: true)
		default:
			break
		}
	}
	
	@IBAction func done(_ sender: Any) {
		delegate?.saveStatesViewControllerDone(self)
	}
	
	@IBAction func newSaveState(_ sender: Any) {
		delegate?.saveStatesViewControllerCreateNewState(self)
	}
	
	override func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 2;
	}

	override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		let reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SaveStateHeader", for: indexPath) as! PVSaveStateHeaderView
		switch indexPath.section {
		case 0:
			reusableView.label.text = "Auto Save"
		case 1:
			reusableView.label.text = "Save States"
		default:
			break
		}

		return reusableView
	}

	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		switch section {
		case 0:
			return autoSaves.count
		case 1:
			return manualSaves.count
		default:
			return 0
		}
	}

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SaveStateView", for: indexPath) as! PVSaveStateCollectionViewCell
		var saveState: PVSaveState?
		switch indexPath.section {
		case 0:
			saveState = autoSaves[indexPath.item]
		case 1:
			saveState = manualSaves[indexPath.item]
		default:
			break
		}

		if let saveState = saveState {
			if let image = saveState.image {
				cell.imageView.image = UIImage(contentsOfFile: image.url.path)
			}
			cell.label.text = "\(dateFormatter.string(from: saveState.date)), \(timeFormatter.string(from: saveState.date))"
		}

		cell.setNeedsLayout()
		cell.layoutIfNeeded()
		return cell
	}

	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		switch indexPath.section {
		case 0:
			let saveState = autoSaves[indexPath.item]
			delegate?.saveStatesViewController(self, load: saveState)
		case 1:
			let saveState = manualSaves[indexPath.item]
			delegate?.saveStatesViewController(self, load: saveState)
		default:
			break
		}
	}
}
