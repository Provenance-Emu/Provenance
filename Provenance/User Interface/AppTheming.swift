//
//  AppTheming.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/22/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import PVThemes
import PVUIBase
import PVUIKit
import PVSwiftUI

@MainActor
func themeAppUI(withPalette palette: any UXThemePalette) {
    applySettingsTheme(palette: palette)
//    applyTableViewCellTheme(palette: palette)
//    applyGameLibraryTheme(palette: palette)
//    applySearchBarTheme(palette: palette)
//    applyGameLibraryHeadersTheme(palette: palette)
}

// MARK: - Settings Theming
@MainActor
private func applySettingsTheme(palette: any UXThemePalette) {
    // Apply theme to various settings view controllers
    appearance(inAny:[
        PVSettingsViewController.self,
        SystemsSettingsTableViewController.self,
        CoreOptionsViewController.self,
        PVAppearanceViewController.self,
        PVCoresTableViewController.self]
    ) {
        UITableViewCell.appearance {
            $0.backgroundColor = palette.settingsCellBackground
            $0.textLabel?.backgroundColor = palette.settingsCellBackground
            $0.textLabel?.textColor = palette.settingsCellText
            $0.detailTextLabel?.textColor = palette.settingsCellText
        }

        SwitchCell.appearance {
            $0.backgroundColor = palette.settingsCellBackground
            $0.textLabel?.backgroundColor = palette.settingsCellBackground
            $0.textLabel?.textColor = palette.settingsCellText
            $0.detailTextLabel?.textColor = palette.settingsCellText
            // Note: Switch control theming is commented out
            // $0.switchControl.onTintColor = theme.switchON
            // $0.switchControl.thumbTintColor = theme.switchThumb
        }

        TapActionCell.appearance {
            $0.backgroundColor = palette.settingsCellBackground
            $0.textLabel?.backgroundColor = palette.settingsCellBackground
            $0.textLabel?.textColor = palette.settingsCellText
            $0.detailTextLabel?.textColor = palette.settingsCellText
        }
    }
}

// MARK: - Table View Cell Theming
@MainActor
private func applyTableViewCellTheme(palette: any UXThemePalette) {
    // Apply theme to table view cells and switch cells
    appearance(in: [UITableViewCell.self, SwitchCell.self]) {
        UILabel.appearance {
            $0.textColor = palette.settingsCellText
        }
    }

    // Set selected background view for cells
    let selectedView = UIView()
    selectedView.backgroundColor = palette.defaultTintColor

    SwitchCell.appearance().selectedBackgroundView = selectedView
    UITableViewCell.appearance().selectedBackgroundView = selectedView
}

// MARK: - Game Library Theming
@MainActor
private func applyGameLibraryTheme(palette: any UXThemePalette) {
    // Apply theme to game library collection view cells
    appearance(inAny: [PVGameLibraryCollectionViewCell.self]) {
        UILabel.appearance {
            $0.textColor = palette.gameLibraryText
        }
    }
}

// MARK: - Search Bar Theming
@MainActor
private func applySearchBarTheme(palette: any UXThemePalette) {
//    appearance(in: UISearchBar.self) {
//        UITextView.appearance {
//            $0.textColor = palette.searchTextColor
//        }
//    }
}

// MARK: - Game Library Headers Theming
@MainActor
private func applyGameLibraryHeadersTheme(palette: any UXThemePalette) {
    PVGameLibrarySectionHeaderView.appearance {
        $0.backgroundColor = palette.gameLibraryHeaderBackground
    }

    appearance(in: [PVGameLibrarySectionHeaderView.self]) {
        UILabel.appearance {
            $0.backgroundColor = palette.gameLibraryHeaderBackground
            $0.textColor = palette.gameLibraryHeaderText
        }
    }
}

