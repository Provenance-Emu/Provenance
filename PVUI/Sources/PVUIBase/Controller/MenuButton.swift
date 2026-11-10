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
    /// Smallest gap from the safe area's left edge.
    static let landscapeLeftMargin: CGFloat = 20
    static let portraitLeftMargin: CGFloat = 10

    var hitAreaInset: UIEdgeInsets = UIEdgeInsets(top: -5, left: -5, bottom: -5, right: -5)

    override func layoutSubviews() {
        super.layoutSubviews()

        if #available(iOS 16.0, tvOS 17.0, *) {
            preferredMenuElementOrder = .priority
        } else {
            // Fallback on earlier versions
        }
        #if !os(tvOS)
        preferredBehavioralStyle = .pad
        #endif
        
        // Ensure the button stays within safe area bounds
        if let superview = superview {
            let safeArea = superview.safeAreaLayoutGuide.layoutFrame
#if !os(tvOS)
            let isLandscape = superview.bounds.width > superview.bounds.height
#else
            let isLandscape = true
#endif
            let minX = safeArea.minX + (isLandscape ? Self.landscapeLeftMargin : Self.portraitLeftMargin)

            if frame.minX < minX {
                frame.origin.x = minX
            }
        }
    }
}
