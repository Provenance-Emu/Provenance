//
//  PVSliderCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

#if canImport(UIKit) && !os(tvOS)
#if canImport(UIKit)
import UIKit
#endif
import PVThemes

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
            slider.tintColor = ThemeManager.shared.currentPalette.defaultTintColor
		#if !targetEnvironment(macCatalyst)
            slider.thumbTintColor = ThemeManager.shared.currentPalette.switchThumb
		#endif
            slider.isContinuous = false
        #endif
        backgroundView = bg
    }
}
#endif
