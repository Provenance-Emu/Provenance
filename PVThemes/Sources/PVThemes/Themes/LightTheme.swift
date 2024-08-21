//
//  LightTheme.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/20/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit.UIColor
#endif

public
struct LightThemePalette: UXThemePalette {
    public var name: String = "Provenance Light"
    public var group: String { "Provenance" }
    public var dark: Bool { false }

    enum Colors {
        static let white9alpha6 = UIColor(white: 0.9, alpha: 0.6)
    }

    public var defaultTintColor: UIColor? { .iOS.blue } // iOS Blue

    public var gameLibraryBackground: UIColor { .white }
    public var gameLibraryText: UIColor { .black }

    public var gameLibraryHeaderBackground: UIColor { Colors.white9alpha6 }
    public var gameLibraryHeaderText: UIColor { .darkGray }

    public var navigationBarBackgroundColor: UIColor? { .grey.g1C }
    public var statusBarColor: UIColor { .grey.g1C }

    public var settingsCellBackground: UIColor? { .white }
    public var settingsCellText: UIColor? { .black }
    public var settingsCellTextDetail: UIColor? { .gray }
}

public
let ProvenanceLightTheme: iOSTheme = .init(name: "Provenance Light", palette: LightThemePalette())
