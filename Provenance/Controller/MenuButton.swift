//
//  MenuButton.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/11/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

final class MenuButton: UIButton, HitAreaEnlarger {
    var hitAreaInset: UIEdgeInsets = UIEdgeInsets(top: -5, left: -5, bottom: -5, right: -5)
}
