//
//  PVSliderCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

#if canImport(UIKit) && !os(tvOS)
import UIKit

final class PVSliderCell: SliderCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.style()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        style()
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        style()
    }

    func style() {
        let bg = UIView(frame: bounds)
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        #if os(iOS)
            slider.tintColor = Theme.currentTheme.defaultTintColor
		#if !targetEnvironment(macCatalyst)
            slider.thumbTintColor = Theme.currentTheme.switchThumb
		#endif
            slider.isContinuous = false
        #endif
        backgroundView = bg
    }
}
#endif
