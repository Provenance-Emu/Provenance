//
//  SettingsTableView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import UIKit

// Subclass to help with themeing
@objc public final class SettingsTableView: UITableView {
    #if os(iOS)
    public override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        self.backgroundColor = Theme.currentTheme.settingsHeaderBackground
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = Theme.currentTheme.settingsHeaderBackground
    }
    #endif
}
