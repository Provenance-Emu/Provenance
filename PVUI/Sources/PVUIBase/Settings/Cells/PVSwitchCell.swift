//
//  SwitchCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/22/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif
import PVThemes

final class PVSwitchCell: SwitchCell {
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
            switchControl.onTintColor = ThemeManager.shared.currentPalette.switchON
		#if !targetEnvironment(macCatalyst)
            switchControl.thumbTintColor = ThemeManager.shared.currentPalette.switchThumb
		#endif
        #endif
        backgroundView = bg
    }
}
