//
//  PVGameLibrarySectionFooterView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/22/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import UIKit

final class PVGameLibrarySectionFooterView: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        let separator = UIView(frame: CGRect(x: 0, y: 0, width: bounds.size.width, height: 1.0))
        separator.backgroundColor = UIColor(white: 1.0, alpha: 0.6)
        separator.autoresizingMask = .flexibleWidth
        addSubview(separator)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
