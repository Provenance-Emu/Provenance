//
//  SystemSettingsHeaderCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

final public class SystemSettingsHeaderCell : SystemSettingsCell {
    override func style() {
        super.style()
        #if os(iOS)
        self.backgroundView?.backgroundColor = Theme.currentTheme.settingsHeaderBackground
        self.textLabel?.textColor = Theme.currentTheme.settingsHeaderText
        self.detailTextLabel?.textColor = Theme.currentTheme.settingsHeaderText
        #else
        self.backgroundView?.backgroundColor = UIColor.clear
        if #available(tvOS 10.0, *) {
            self.textLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.white : UIColor.black
            self.detailTextLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.lightGray : UIColor.darkGray
        }
        #endif
        self.textLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
    }
}
