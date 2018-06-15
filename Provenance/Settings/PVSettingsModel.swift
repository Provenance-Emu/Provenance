//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVSettingsModel.swift
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import Foundation

let kAutoSaveKey = "kAutoSaveKey"
let kAutoLoadSavesKey = "kAutoLoadSavesKey"
let kControllerOpacityKey = "kControllerOpacityKey"
let kAskToAutoLoadKey = "kAskToAutoLoadKey"
let kDisableAutoLockKey = "kDisableAutoLockKey"
let kButtonVibrationKey = "kButtonVibrationKey"
let kImageSmoothingKey = "kImageSmoothingKey"
let kCRTFilterKey = "kCRTFilterKey"
let kShowRecentGamesKey = "kShowRecentGamesKey"
let kShowRecentSavesKey = "kShowRecentSavesKey"
let kICadeControllerSettingKey = "kiCadeControllerSettingKey"
let kVolumeSettingKey = "kVolumeSettingKey"
let kFPSCountKey = "kFPSCountKey"
let kShowGameTitlesKey = "kShowGameTitlesKey"
let kWebDayAlwwaysOnKey = "kWebDavAlwaysOnKey"
let kThemeKey = "kThemeKey"
let kButtonTintsKey = "kButtonsTintsKey"
let kStartSelectAlwaysOnKey = "kStartSelectAlwaysOnKey"
let kAllRightShouldersKey = "kAllRightShouldersKey"
let kVolumeHUDKey = "kVolumeHUDKey"

public class PVSettingsModel: NSObject {

    @objc
    var autoSave: Bool {
        didSet {
            UserDefaults.standard.set(autoSave, forKey: kAutoSaveKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var askToAutoLoad: Bool {
      didSet {
            UserDefaults.standard.set(askToAutoLoad, forKey: kAskToAutoLoadKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var autoLoadSaves: Bool {
       didSet {
            UserDefaults.standard.set(autoLoadSaves, forKey: kAutoLoadSavesKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var disableAutoLock: Bool {
       didSet {
            UserDefaults.standard.set(disableAutoLock, forKey: kDisableAutoLockKey)
            UserDefaults.standard.synchronize()
            UIApplication.shared.isIdleTimerDisabled = disableAutoLock
        }
    }

    @objc
    var buttonVibration: Bool {
        didSet {
            UserDefaults.standard.set(buttonVibration, forKey: kButtonVibrationKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var imageSmoothing: Bool {
        didSet {
            UserDefaults.standard.set(imageSmoothing, forKey: kImageSmoothingKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var crtFilterEnabled: Bool {
        didSet {
            UserDefaults.standard.set(crtFilterEnabled, forKey: kCRTFilterKey)
            UserDefaults.standard.synchronize()
        }
    }

	@objc
	var showRecentSaveStates: Bool {
		didSet {
			UserDefaults.standard.set(showRecentSaveStates, forKey: kShowRecentSavesKey)
			UserDefaults.standard.synchronize()
		}
	}

    @objc
    var showRecentGames: Bool {
        didSet {
            UserDefaults.standard.set(showRecentGames, forKey: kShowRecentGamesKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var showFPSCount: Bool {
        didSet {
            UserDefaults.standard.set(showFPSCount, forKey: kFPSCountKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var showGameTitles: Bool {
        didSet {
            UserDefaults.standard.set(showGameTitles, forKey: kShowGameTitlesKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var webDavAlwaysOn: Bool {
        didSet {
            UserDefaults.standard.set(webDavAlwaysOn, forKey: kWebDayAlwwaysOnKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var myiCadeControllerSetting: iCadeControllerSetting {
        didSet {
            UserDefaults.standard.set(myiCadeControllerSetting.rawValue, forKey: kICadeControllerSettingKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var controllerOpacity: CGFloat {
        didSet {
            UserDefaults.standard.set(Float(controllerOpacity), forKey: kControllerOpacityKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var buttonTints: Bool {
        didSet {
            UserDefaults.standard.set(buttonTints, forKey: kButtonTintsKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var startSelectAlwaysOn: Bool {
        didSet {
            UserDefaults.standard.set(startSelectAlwaysOn, forKey: kStartSelectAlwaysOnKey)
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    var allRightShoulders: Bool {
        didSet {
            UserDefaults.standard.set(allRightShoulders, forKey: kAllRightShouldersKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    @objc
    var volume: Float {
        didSet {
            UserDefaults.standard.set(volume, forKey: kVolumeSettingKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    @objc
    var volumeHUD: Bool {
        didSet {
            UserDefaults.standard.set(volumeHUD, forKey: kVolumeHUDKey)
            UserDefaults.standard.synchronize()
        }
    }

    #if os(iOS)
    var theme: Themes {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: kThemeKey)
            UserDefaults.standard.synchronize()
        }
    }
    #endif

    static var shared = PVSettingsModel()

    @objc
    class func sharedInstance() -> PVSettingsModel {
        return PVSettingsModel.shared
    }

    override init() {
        #if os(iOS)
        let theme = Themes.defaultTheme.rawValue
        #else
        let theme = ""
        #endif

        UserDefaults.standard.register(defaults: [kAutoSaveKey: true,
                                                  kAskToAutoLoadKey: true,
                                                  kAutoLoadSavesKey: false,
                                                  kControllerOpacityKey: 0.8,
                                                  kDisableAutoLockKey: false,
                                                  kButtonVibrationKey: true,
                                                  kImageSmoothingKey: false,
                                                  kCRTFilterKey: false,
                                                  kShowRecentGamesKey: true,
												  kShowRecentSavesKey: true,
                                                  kICadeControllerSettingKey: iCadeControllerSetting.settingDisabled.rawValue,
                                                  kVolumeSettingKey: 1.0,
                                                  kFPSCountKey: false,
                                                  kShowGameTitlesKey: true,
                                                  kWebDayAlwwaysOnKey: false,
                                                  kButtonTintsKey: false,
                                                  kStartSelectAlwaysOnKey: false,
                                                  kAllRightShouldersKey: false,
                                                  kVolumeHUDKey: true,
                                                  kThemeKey: theme])
        UserDefaults.standard.synchronize()

        autoSave = UserDefaults.standard.bool(forKey: kAutoSaveKey)
        autoLoadSaves = UserDefaults.standard.bool(forKey: kAutoLoadSavesKey)
        controllerOpacity = CGFloat(UserDefaults.standard.float(forKey: kControllerOpacityKey))
        disableAutoLock = UserDefaults.standard.bool(forKey: kDisableAutoLockKey)
        buttonVibration = UserDefaults.standard.bool(forKey: kButtonVibrationKey)
        imageSmoothing = UserDefaults.standard.bool(forKey: kImageSmoothingKey)
        crtFilterEnabled = UserDefaults.standard.bool(forKey: kCRTFilterKey)
		showRecentSaveStates = UserDefaults.standard.bool(forKey: kShowRecentSavesKey)
        showRecentGames = UserDefaults.standard.bool(forKey: kShowRecentGamesKey)
        let iCade = UserDefaults.standard.integer(forKey: kICadeControllerSettingKey)
        myiCadeControllerSetting = iCadeControllerSetting(rawValue: Int(iCade))!
        volume = UserDefaults.standard.float(forKey: kVolumeSettingKey)
        showFPSCount = UserDefaults.standard.bool(forKey: kFPSCountKey)
        showGameTitles = UserDefaults.standard.bool(forKey: kShowGameTitlesKey)
        webDavAlwaysOn = UserDefaults.standard.bool(forKey: kWebDayAlwwaysOnKey)
        askToAutoLoad = UserDefaults.standard.bool(forKey: kAskToAutoLoadKey)
        buttonTints = UserDefaults.standard.bool(forKey: kButtonTintsKey)
        startSelectAlwaysOn = UserDefaults.standard.bool(forKey: kStartSelectAlwaysOnKey)
        allRightShoulders = UserDefaults.standard.bool(forKey: kAllRightShouldersKey)
        volumeHUD = UserDefaults.standard.bool(forKey: kVolumeHUDKey)

        #if os(iOS)
        let themeString = UserDefaults.standard.string(forKey: kThemeKey) ?? Themes.defaultTheme.rawValue
        self.theme = Themes(rawValue: themeString) ?? Themes.defaultTheme
        #endif

        super.init()
    }
}
