//
//  SwitchCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/22/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import QuickTableViewController
import UIKit

final class PVSwitchCell: SwitchCell {
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
            textLabel?.textColor = Theme.currentTheme.settingsCellText
            detailTextLabel?.textColor = Theme.currentTheme.defaultTintColor
            switchControl.onTintColor = Theme.currentTheme.switchON
            switchControl.thumbTintColor = Theme.currentTheme.switchThumb

        #else
            bg.backgroundColor = UIColor.clear
            if #available(tvOS 10.0, *) {
                self.textLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.white : UIColor.black
                self.detailTextLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.lightGray : UIColor.darkGray
            }
        #endif
        backgroundView = bg
    }
}
