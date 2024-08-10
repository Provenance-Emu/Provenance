//
//  SettingsOptionRow.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/17/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVSettings

public final class PVSettingsOptionRow: RadioSection {
    let keyPath: Defaults.Key<String>
    let _options: [String]
    let _rows: [OptionRow<UITableViewCell>]
    var selectedValue: String { Defaults[keyPath] }

//    private func didToggleSelection() -> (Row) -> Void {
//      return { [weak self] in
//        if let option = $0 as? OptionRowCompatible {
//          let state = "\(option.text) is " + (option.isSelected ? "selected" : "deselected")
//          self?.showDebuggingText(state)
//        }
//      }
//    }

    required init(title: String,
                  footer: String? = nil,
                  key: Defaults.Key<String>,
                  options: [String]) {
        self._options = options
        keyPath = key
        let _selected: String = Defaults[keyPath]
        _rows = options.map {
            let selected: Bool
            if $0.lowercased() == "off" {
                selected = _selected == ""
            } else {
                selected = $0 == _selected
            }
            return OptionRow(text: $0, isSelected: selected, action: { row in
                if let option = row as? OptionRowCompatible {
                    if option.isSelected {
                        var value = option.text
                        if value.lowercased() == "off" { value = "" }
                        Defaults[key] = value
                    }
                }
            })
        }

        super.init(title: title, options: _rows, footer: footer)
    }
}
