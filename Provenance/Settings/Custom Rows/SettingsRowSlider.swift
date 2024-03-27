//
//  SettingsRowSlider.swift
//  Provenance
//
//  Created by Joseph Mattiello on 12/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
#if os(iOS)

final class PVSettingsSliderRow<T>: SliderRow<PVSliderCell> where T: BinaryFloatingPoint {
    let keyPath: ReferenceWritableKeyPath<PVSettingsModel, T>

    required init(text: String,
                  detailText: DetailText? = nil,
                  valueLimits: (min: Float, max: Float),
                  valueImages: (min: Icon?, max: Icon?) = (min: nil, max: nil),
                  key: ReferenceWritableKeyPath<PVSettingsModel, T>,
                  customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil) {
        keyPath = key
        let value = PVSettingsModel.shared[keyPath: key]

        super.init(
            text: text,
            detailText: detailText,
            value: Float(value),
            valueLimits: valueLimits,
            valueImages: valueImages,
            customization: customization, action: { row in
                if let row = row as? SliderRowCompatible {
                    PVSettingsModel.shared[keyPath: key] = T(row.value)
                }
            }
        )
    }
}
#endif
