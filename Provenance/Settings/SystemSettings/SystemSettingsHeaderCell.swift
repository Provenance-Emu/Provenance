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
        #if os(tvOS)
            backgroundView?.backgroundColor = UIColor.clear
            textLabel?.textColor = .white
            detailTextLabel?.textColor = .lightGray
            textLabel?.font = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.regular)
            detailTextLabel?.font = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.regular)
        #endif
    }
}
