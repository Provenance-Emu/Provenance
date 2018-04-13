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

	weak var saveState: PVSaveState? {
		didSet {
			if let saveState = saveState {
				if let image = saveState.image {
					imageView.image = UIImage(contentsOfFile: image.url.path)
				}
				let timeText = "\(PVSaveStateCollectionViewCell.dateFormatter.string(from: saveState.date)), \(PVSaveStateCollectionViewCell.timeFormatter.string(from: saveState.date))"
				if label.numberOfLines > 1 {
					label.text = "\(saveState.game.title)\n\(timeText)"
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
