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
	@IBOutlet weak var label: UILabel!
	@IBOutlet weak var secondLabel: UILabel!

	weak var saveState: PVSaveState? {
		didSet {
			if let saveState = saveState {
				if let image = saveState.image {
					imageView.image = UIImage(contentsOfFile: image.url.path)
                    imageView.layer.borderWidth = 1.0
                    imageView.layer.borderColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3).cgColor
                }
				let timeText = "\(PVSaveStateCollectionViewCell.dateFormatter.string(from: saveState.date)), \(PVSaveStateCollectionViewCell.timeFormatter.string(from: saveState.date))"

				let multipleCores = saveState.game.system.cores.count > 1
				let system = saveState.game.system
				var coreOrSystem : String = (multipleCores ? saveState.core.projectName : system?.shortNameAlt ?? system?.shortName ?? "")
				if coreOrSystem.count > 0 {
					coreOrSystem = " " + coreOrSystem
				}

				label.text = saveState.game.title
				secondLabel.text = timeText + coreOrSystem
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
//		self.label.alpha = 0
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
		super.didUpdateFocus(in: context, with: coordinator)

		coordinator.addCoordinatedAnimations({() -> Void in
			if self.isFocused {
				let yTrasform = self.label.bounds.height * -0.25
				var transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
				transform = transform.translatedBy(x: 0, y: yTrasform * 2.0)
//				self.label.alpha = 1
				self.label.transform = transform.translatedBy(x: 0, y: yTrasform + 1)
//				self.secondLabel.alpha = 1
				self.secondLabel.transform = transform

				self.superview?.bringSubview(toFront: self)

				let labelBGColor = UIColor.black.withAlphaComponent(0.8)
				self.label.backgroundColor = labelBGColor
				self.secondLabel.backgroundColor = labelBGColor
			} else {
//				self.label.alpha = 0
				self.label.transform = .identity
//				self.secondLabel.alpha = 0
				self.secondLabel.transform = .identity

				let labelBGColor = UIColor.clear
				self.label.backgroundColor = labelBGColor
				self.secondLabel.backgroundColor = labelBGColor
			}
		}) {() -> Void in }
	}
#endif
}
