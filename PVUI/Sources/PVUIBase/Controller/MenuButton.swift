//
//  MenuButton.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/11/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif

final class MenuButton: UIButton, HitAreaEnlarger {
    var hitAreaInset: UIEdgeInsets = UIEdgeInsets(top: -5, left: -5, bottom: -5, right: -5)

    override func layoutSubviews() {
        super.layoutSubviews()

        // Ensure the button stays within safe area bounds
        if let superview = superview {
            let safeArea = superview.safeAreaLayoutGuide.layoutFrame
            let isLandscape = UIDevice.current.orientation.isLandscape
            let minX = safeArea.minX + (isLandscape ? 20 : 10)

            if frame.minX < minX {
                frame.origin.x = minX
            }
        }
    }
}
