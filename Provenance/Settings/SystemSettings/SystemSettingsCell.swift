//
//  SystemSettingsCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public class SystemSettingsCell: UITableViewCell {
    public static let identifier: String = String(describing: self)

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.style()
    }

    public required init?(coder aDecoder: NSCoder) {
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
