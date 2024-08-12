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

func themeAppUI(withTheme theme: iOSTheme) {
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
                $0.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.textColor = theme.settingsCellText
                $0.detailTextLabel?.textColor = theme.settingsCellText
            }
            
            SwitchCell.appearance {
                $0.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.textColor = theme.settingsCellText
                $0.detailTextLabel?.textColor = theme.settingsCellText
                //                $0.switchControl.onTintColor = theme.switchON
                //                $0.switchControl.thumbTintColor = theme.switchThumb
            }
            
            TapActionCell.appearance {
                $0.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.backgroundColor = theme.settingsCellBackground
                $0.textLabel?.textColor = theme.settingsCellText
                $0.detailTextLabel?.textColor = theme.settingsCellText
            }
        }
    }
    
    Task { @MainActor in
        appearance(in: [UITableViewCell.self, SwitchCell.self]) {
            UILabel.appearance {
                $0.textColor = theme.settingsCellText
            }
        }
    }
    
    let selectedView = UIView()
    selectedView.backgroundColor = theme.defaultTintColor
    
    SwitchCell.appearance().selectedBackgroundView = selectedView
    UITableViewCell.appearance().selectedBackgroundView = selectedView
    
#if false
    // Search bar
    appearance(in: UISearchBar.self) {
        UITextView.appearance {
            $0.textColor = theme.searchTextColor
        }
    }
    
    // Game Library Headers
    PVGameLibrarySectionHeaderView.appearance {
        $0.backgroundColor = theme.gameLibraryHeaderBackground
    }
    
    appearance(in: [PVGameLibrarySectionHeaderView.self]) {
        UILabel.appearance {
            $0.backgroundColor = theme.gameLibraryHeaderBackground
            $0.textColor = theme.gameLibraryHeaderText
        }
    }
#endif
    
    // Game Library Main
    Task { @MainActor in
        appearance(inAny: [PVGameLibraryCollectionViewCell.self]) {
            UILabel.appearance {
                $0.textColor = theme.gameLibraryText
            }
        }
    }
}
