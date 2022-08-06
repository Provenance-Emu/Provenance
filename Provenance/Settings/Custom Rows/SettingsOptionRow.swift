//
//  SettingsOptionRow.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/17/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import PVSupport

public
final class PVRadioOptionCell: UITableViewCell {
    public static let identifier: String = String(describing: PVRadioOptionCell.self)

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
//            switchControl.onTintColor = Theme.currentTheme.switchON
        #if !targetEnvironment(macCatalyst)
//            switchControl.thumbTintColor = Theme.currentTheme.switchThumb
        #endif
        #else
            bg.backgroundColor = UIColor.clear
            self.textLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.white : UIColor.black
            self.detailTextLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.lightGray : UIColor.darkGray
        #endif
        backgroundView = bg
    }
}

public
final class PVRadioOptionRow: OptionRow<PVRadioOptionCell> {
    
}

public
final class PVSettingsOptionRow: RadioSection {
    let keyPath: ReferenceWritableKeyPath<PVSettingsModel, String>
    let _options: [String]
    let _rows: [PVRadioOptionRow]
    var selectedValue: String { PVSettingsModel.shared[keyPath: keyPath] }
    
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
                  key: ReferenceWritableKeyPath<PVSettingsModel, String>,
                  options: [String]) {
        self._options = options
        keyPath = key
        let _selected = PVSettingsModel.shared[keyPath: keyPath]
        _rows = options.map {
            let selected: Bool
            if $0.lowercased() == "off" {
                selected = _selected == ""
            } else {
                selected = $0 == _selected
            }
            return PVRadioOptionRow(text: $0, isSelected: selected, action: { row in
                if let option = row as? OptionRowCompatible {
                    if option.isSelected {
                        var value = option.text
                        if value.lowercased() == "off" { value = "" }
                        PVSettingsModel.shared[keyPath: key] = value
                    }
                }
            })
        }
        
        super.init(title: title, options: _rows, footer: footer)
    }
}
