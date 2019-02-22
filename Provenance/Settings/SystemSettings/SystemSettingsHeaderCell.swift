//
//  SystemSettingsHeaderCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public final class SystemSettingsHeaderCell: SystemSettingsCell {
    override func style() {
        super.style()
        #if os(iOS)
            backgroundView?.backgroundColor = Theme.currentTheme.settingsHeaderBackground
            textLabel?.textColor = Theme.currentTheme.settingsHeaderText
            detailTextLabel?.textColor = Theme.currentTheme.settingsHeaderText
        #else
            backgroundView?.backgroundColor = UIColor.clear
            if #available(tvOS 10.0, *) {
                self.textLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.white : UIColor.black
                self.detailTextLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.lightGray : UIColor.darkGray
            }
        #endif
        textLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
    }
}
