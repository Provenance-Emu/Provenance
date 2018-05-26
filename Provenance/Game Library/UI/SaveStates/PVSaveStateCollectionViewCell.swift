//
//  PVSaveStateCollectionViewCell.swift
//  Provenance
//
//  Created by James Addyman on 30/03/2018.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

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
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var timeStampLabel: UILabel!
    @IBOutlet weak var coreLabel: UILabel!
    
	weak var saveState: PVSaveState? {
		didSet {
			if let saveState = saveState {
				if let image = saveState.image {
					imageView.image = UIImage(contentsOfFile: image.url.path)
                    imageView.layer.borderWidth = 1.0
                    imageView.layer.borderColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3).cgColor
                }
				let timeText = "\(PVSaveStateCollectionViewCell.dateFormatter.string(from: saveState.date)) \(PVSaveStateCollectionViewCell.timeFormatter.string(from: saveState.date))"

				let multipleCores = saveState.game.system.cores.count > 1
				let system = saveState.game.system
				var coreOrSystem : String = (multipleCores ? saveState.core.projectName : system?.shortNameAlt ?? system?.shortName ?? "")
				if coreOrSystem.count > 0 {
					coreOrSystem = " " + coreOrSystem
				}

				titleLabel.text = saveState.game.title
				timeStampLabel.text = timeText
                coreLabel.text = system?.shortName
			}

			setNeedsLayout()
			layoutIfNeeded()
		}
	}

	override func prepareForReuse() {
		super.prepareForReuse()

		imageView.image = nil
		titleLabel.text = nil
#if os(tvOS)
//		self.label.alpha = 0
		self.titleLabel.transform = .identity
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
		super.didUpdateFocus(in: context, with: coordinator)

		coordinator.addCoordinatedAnimations({() -> Void in
			if self.isFocused {
				let yTrasform = self.titleLabel.bounds.height * -0.25
				var transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
				transform = transform.translatedBy(x: 0, y: yTrasform * 2.0)
//				self.label.alpha = 1
				self.titleLabel.transform = transform.translatedBy(x: 0, y: yTrasform + 1)
//				self.secondLabel.alpha = 1
				self.timeStampLabel.transform = transform

				self.superview?.bringSubview(toFront: self)

				let labelBGColor = UIColor.black.withAlphaComponent(0.8)
				self.titleLabel.backgroundColor = labelBGColor
				self.timeStampLabel.backgroundColor = labelBGColor
			} else {
//				self.label.alpha = 0
				self.titleLabel.transform = .identity
//				self.secondLabel.alpha = 0
				self.timeStampLabel.transform = .identity

				let labelBGColor = UIColor.clear
				self.titleLabel.backgroundColor = labelBGColor
				self.timeStampLabel.backgroundColor = labelBGColor
			}
		}) {() -> Void in }
	}
#endif
}
