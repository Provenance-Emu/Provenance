//
//  PVThemesTests.swift
//  PVSupportTests
//
//  Created by Joseph Mattiello on 11/22/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

@testable import PVThemes
import UIKit
import XCTest

class PVThemesTests: XCTestCase {
    func testPremiumPaletteTextContrast() {
        let palettes = CGAThemes.allCases.map(\.palette) + [ProvenanceThemes.retrowave.palette]
        for palette in palettes {
            let pairs: [(UIColor, UIColor)] = [
                (palette.gameLibraryText, palette.gameLibraryBackground),
                (palette.gameLibraryCellText, palette.gameLibraryCellBackground ?? palette.gameLibraryBackground),
                (palette.gameLibraryHeaderText, palette.gameLibraryHeaderBackground),
                (palette.settingsCellText ?? palette.gameLibraryText, palette.settingsCellBackground ?? palette.gameLibraryBackground),
                (palette.menuText, palette.menuBackground),
                (palette.defaultTintColor, palette.gameLibraryBackground)
            ]
            for (text, background) in pairs {
                XCTAssertGreaterThanOrEqual(contrast(text, background), 4.5, "\(palette.name) has insufficient text contrast")
            }
        }
    }

    func testPaletteRolesSurviveProtocolDispatch() {
        for theme in CGAThemes.allCases.filter({ $0 != .random }) {
            let palette = theme.palette
            XCTAssertNotNil(palette.gameLibraryCellBackground, palette.name)
            XCTAssertNotNil(palette.settingsCellTextDetail, palette.name)
            XCTAssertNotEqual(palette.gameLibraryBackground, palette.gameLibraryCellBackground, palette.name)
            XCTAssertEqual(palette.gameLibraryCellText, palette.settingsCellText, palette.name)
            XCTAssertEqual(palette.dark, palette.keyboardAppearance == .dark, palette.name)
        }
    }

    private func contrast(_ first: UIColor, _ second: UIColor) -> CGFloat {
        let values = [luminance(first), luminance(second)].sorted()
        return (values[1] + 0.05) / (values[0] + 0.05)
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
