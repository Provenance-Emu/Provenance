//
//  PVSaveStateCollectionViewCell.swift
//  Provenance
//
//  Created by James Addyman on 30/03/2018.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

class PVSaveStateCollectionViewCell: UICollectionViewCell {
    
	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var noScreenshotLabel: UILabel!
	@IBOutlet weak var label: UILabel!
	
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
