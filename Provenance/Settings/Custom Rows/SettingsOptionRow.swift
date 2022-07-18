//
//  SettingsOptionRow.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/17/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

final class PVOptionCell: TapActoinCell {
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
        #if !targetEnvironment(macCatalyst)
            switchControl.thumbTintColor = Theme.currentTheme.switchThumb
        #endif
        #else
            bg.backgroundColor = UIColor.clear
            self.textLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.white : UIColor.black
            self.detailTextLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.lightGray : UIColor.darkGray
        #endif
        backgroundView = bg
    }
}


final class PVSettingsOptionRow: OptionRow<PVOptionCell> {
    let keyPath: ReferenceWritableKeyPath<PVSettingsModel, [String]>

    required init(text: String,
                  detailText: DetailText? = nil,
                  key: ReferenceWritableKeyPath<PVSettingsModel, String>,
                  customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil) {
        keyPath = key
        let value = PVSettingsModel.shared[keyPath: key]

        super.init(text: text, detailText: detailText, switchValue: value, customization: customization, action: { row in
            if let row = row as? SwitchRowCompatible {
                PVSettingsModel.shared[keyPath: key] = row.switchValue
            }
        })
    }
}
