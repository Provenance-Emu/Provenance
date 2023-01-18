//
//  SettingsRowSwitch.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

final class PVSettingsSwitchRow: SwitchRow<PVSwitchCell> {
    let keyPath: ReferenceWritableKeyPath<PVSettingsModel, Bool>

    required init(text: String, detailText: DetailText? = nil, key: ReferenceWritableKeyPath<PVSettingsModel, Bool>, icon: Icon? = nil, customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil) {
        keyPath = key
        let value = PVSettingsModel.shared[keyPath: key]

        super.init(text: text, detailText: detailText, switchValue: value, icon: icon, customization: customization, action: { row in
            if let row = row as? SwitchRowCompatible {
                PVSettingsModel.shared[keyPath: key] = row.switchValue
            }
        })
    }
}
