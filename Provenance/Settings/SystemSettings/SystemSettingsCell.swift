//
//  SystemSettingsCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public class SystemSettingsCell: UITableViewCell {
    public static let identifier: String = String(describing: SystemSettingsCell.self)

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
        #if os(tvOS)
            bg.backgroundColor = UIColor.clear
            self.textLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.white : UIColor.black
            self.detailTextLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.lightGray : UIColor.darkGray
            self.textLabel?.font = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.regular)
            self.detailTextLabel?.font = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.regular)
        #endif
        backgroundView = bg
    }
}
