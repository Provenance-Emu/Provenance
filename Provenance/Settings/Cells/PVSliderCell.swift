//
//  PVSliderCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import UIKit
import QuickTableViewController

final class PVSliderCell : SliderCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.style()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        style()
    }

    func style() {
        let bg = UIView(frame: bounds)
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        #if os(iOS)
        bg.backgroundColor = Theme.currentTheme.settingsCellBackground
        self.textLabel?.textColor = Theme.currentTheme.settingsCellText
        self.detailTextLabel?.textColor = Theme.currentTheme.defaultTintColor
        self.slider.tintColor = Theme.currentTheme.defaultTintColor
        self.slider.thumbTintColor = Theme.currentTheme.switchThumb
        self.slider.isContinuous = false
        #else
        bg.backgroundColor = UIColor.clear
        if #available(tvOS 10.0, *) {
            self.textLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.white : UIColor.black
            self.detailTextLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.lightGray : UIColor.darkGray
        }
        #endif
        self.backgroundView = bg
    }
}
