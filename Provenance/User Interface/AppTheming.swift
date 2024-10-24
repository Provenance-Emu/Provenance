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

func themeAppUI(withPalette palette: any UXThemePalette) {
    // Settings
    Task { @MainActor in
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
                //                $0.switchControl.onTintColor = theme.switchON
                //                $0.switchControl.thumbTintColor = theme.switchThumb
            }
            
            TapActionCell.appearance {
                $0.backgroundColor = palette.settingsCellBackground
                $0.textLabel?.backgroundColor = palette.settingsCellBackground
                $0.textLabel?.textColor = palette.settingsCellText
                $0.detailTextLabel?.textColor = palette.settingsCellText
            }
        }
    }
    
    Task { @MainActor in
        appearance(in: [UITableViewCell.self, SwitchCell.self]) {
            UILabel.appearance {
                $0.textColor = palette.settingsCellText
            }
        }
    }
    
    let selectedView = UIView()
    selectedView.backgroundColor = palette.defaultTintColor
    
    SwitchCell.appearance().selectedBackgroundView = selectedView
    UITableViewCell.appearance().selectedBackgroundView = selectedView
    
#if false
    // Search bar
    appearance(in: UISearchBar.self) {
        UITextView.appearance {
            $0.textColor = palette.searchTextColor
        }
    }
    
    // Game Library Headers
    PVGameLibrarySectionHeaderView.appearance {
        $0.backgroundColor = palette.gameLibraryHeaderBackground
    }
    
    appearance(in: [PVGameLibrarySectionHeaderView.self]) {
        UILabel.appearance {
            $0.backgroundColor = palette.gameLibraryHeaderBackground
            $0.textColor = palette.gameLibraryHeaderText
        }
    }
#endif
    
    // Game Library Main
    Task { @MainActor in
        appearance(inAny: [PVGameLibraryCollectionViewCell.self]) {
            UILabel.appearance {
                $0.textColor = palette.gameLibraryText
            }
        }
    }
}
