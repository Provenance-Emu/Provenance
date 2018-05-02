//
//  PVSaveStateCollectionViewCell.swift
//  Provenance
//
//  Created by James Addyman on 30/03/2018.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

protocol SaveStateCollectionDelegate {
	func didSelectSaveState(_ : PVSaveState)
}

class SaveStatesCollectionCell: UICollectionViewCell, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

	private let cellId = "SaveStateView"

	lazy var saveStates: Results<PVSaveState> = {
		return PVSaveState.all.filter("game != nil").sorted(byKeyPath: #keyPath(PVSaveState.lastOpened), ascending: false).sorted(byKeyPath: #keyPath(PVSaveState.date), ascending: false)
	}()

	var selectionDelegate : SaveStateCollectionDelegate?
	var savesStatesToken: NotificationToken?

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
		setupToken()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutMarginsDidChange() {
		super.layoutMarginsDidChange()
		saveStatesCollectionView.flashScrollIndicators()
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		selectionDelegate = nil
		savesStatesToken?.invalidate()
		savesStatesToken = nil
	}

	let saveStatesCollectionView: UICollectionView = {
		let layout = UICollectionViewFlowLayout()
		layout.scrollDirection = .horizontal
		layout.itemSize = CGSize(width: 150, height: 150)
		layout.minimumLineSpacing = 0
		layout.minimumInteritemSpacing = 10

		let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
		collectionView.showsHorizontalScrollIndicator = false
		collectionView.showsVerticalScrollIndicator = false
		collectionView.isPagingEnabled = true
		collectionView.scrollIndicatorInsets = UIEdgeInsetsMake(2, 2, 0, 2)
		collectionView.indicatorStyle = .white
		return collectionView
	}()

	func setupViews() {
		backgroundColor = Theme.currentTheme.gameLibraryBackground

		addSubview(saveStatesCollectionView)

		saveStatesCollectionView.delegate = self
		saveStatesCollectionView.dataSource = self

	#if os(tvOS)
		saveStatesCollectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: cellId)
	#else
		saveStatesCollectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: cellId)
	#endif
//		saveStatesCollectionView.register(PVSaveStateCollectionViewCell.self, forCellWithReuseIdentifier: cellId)

		saveStatesCollectionView.frame = self.bounds

		if #available(iOS 9.0, *) {
			let margins = self.layoutMarginsGuide

			saveStatesCollectionView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 8).isActive = true
			saveStatesCollectionView.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: 8).isActive = true
			saveStatesCollectionView.heightAnchor.constraint(equalTo: margins.heightAnchor, constant: 0).isActive = true
		} else {
			NSLayoutConstraint(item: saveStatesCollectionView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leadingMargin, multiplier: 1.0, constant: 8.0).isActive = true
			NSLayoutConstraint(item: saveStatesCollectionView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailingMargin, multiplier: 1.0, constant: 8.0).isActive = true
			NSLayoutConstraint(item: saveStatesCollectionView, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant:0.0).isActive = true
		}

		saveStatesCollectionView.backgroundColor = Theme.currentTheme.gameLibraryBackground

		//saveStatesCollectionView
	}
	// MARK: - UICollectionViewDelegate
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let saveState = saveStates[indexPath.row]
		selectionDelegate?.didSelectSaveState(saveState)
	}


	// MARK: - UICollectionViewDataSource
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		let count = saveStates.count
		return count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let cell = saveStatesCollectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as? PVSaveStateCollectionViewCell else {
			fatalError("Couldn't create cell of type PVGameLibraryCollectionViewSaveStatesCellIdentifier")
		}

		if indexPath.row < saveStates.count {
			let saveState = saveStates[indexPath.row]
			cell.saveState = saveState
		}

		return cell
	}
	

	// ----
	private func setupToken() {
		savesStatesToken = saveStates.observe { [unowned self] (changes: RealmCollectionChange) in
			switch changes {
			case .initial(let result):
				self.saveStatesCollectionView.reloadData()
			case .update(_, let deletions, let insertions, let modifications):
				// Query results have changed, so apply them to the UICollectionView
				self.handleUpdate(deletions: deletions, insertions: insertions, modifications: modifications)
			case .error(let error):
				// An error occurred while opening the Realm file on the background worker thread
				fatalError("\(error)")
			}
		}
	}

	private func handleUpdate( deletions: [Int], insertions: [Int], modifications: [Int]) {
		saveStatesCollectionView.reloadData()
//		saveStatesCollectionView.performBatchUpdates({
//			ILOG("Section SaveStates updated with Insertions<\(insertions.count)> Mods<\(modifications.count)> Deletions<\(deletions.count)>")
//			saveStatesCollectionView.insertItems(at: insertions.map({ return IndexPath(row: $0, section: 0) }))
//			saveStatesCollectionView.deleteItems(at: deletions.map({  return IndexPath(row: $0, section: 0) }))
//			saveStatesCollectionView.reloadItems(at: modifications.map({  return IndexPath(row: $0, section: 0) }))
//		}, completion: { (completed) in
//
//		})
	}
}

class PVSaveStateCollectionViewCell: UICollectionViewCell {

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

	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var noScreenshotLabel: UILabel!
	@IBOutlet weak var label: UILabel!

	weak var saveState: PVSaveState? {
		didSet {
			if let saveState = saveState {
				if let image = saveState.image {
					imageView.image = UIImage(contentsOfFile: image.url.path)
				}
				let timeText = "\(PVSaveStateCollectionViewCell.dateFormatter.string(from: saveState.date)), \(PVSaveStateCollectionViewCell.timeFormatter.string(from: saveState.date))"
				if label.numberOfLines > 1 {
					let multipleCores = saveState.game.system.cores.count > 1
					let system = saveState.game.system
					var coreOrSystem : String = (multipleCores ? saveState.core.projectName : system?.shortNameAlt ?? system?.shortName ?? "")
					if coreOrSystem.count > 0 {
						coreOrSystem = " " + coreOrSystem
					}
					label.text = "\(saveState.game.title)\n\(timeText)" + coreOrSystem
				} else {
					label.text = timeText
				}
			}

			setNeedsLayout()
			layoutIfNeeded()
		}
	}

	override func prepareForReuse() {
		super.prepareForReuse()

		imageView.image = nil
		label.text = nil
#if os(tvOS)
		self.label.alpha = 0
		self.label.transform = .identity
#endif
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		if imageView.image == nil {
			noScreenshotLabel.isHidden = false
		} else {
			noScreenshotLabel.isHidden = true
		}
	}

#if os(tvOS)
	override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
		coordinator.addCoordinatedAnimations({() -> Void in
			if self.isFocused {
				var transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
				transform = transform.translatedBy(x: 0, y: 0)
				self.label.alpha = 1
				self.label.transform = transform
			} else {
				self.label.alpha = 0
				self.label.transform = .identity
			}
		}) {() -> Void in }
	}
#endif
}
