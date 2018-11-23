//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVSettingsModel.swift
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import Foundation

private func minutes(_ minutes : Double) -> TimeInterval {
    return TimeInterval(60 * minutes)
}

//let kAutoSaveKey = "kAutoSaveKey"
//let kAutoLoadSavesKey = "kAutoLoadSavesKey"
//let kControllerOpacityKey = "kControllerOpacityKey"
//let kAskToAutoLoadKey = "kAskToAutoLoadKey"
//let kDisableAutoLockKey = "kDisableAutoLockKey"
//let kButtonVibrationKey = "kButtonVibrationKey"
//let kImageSmoothingKey = "kImageSmoothingKey"
//let kCRTFilterKey = "kCRTFilterKey"
//let kNativeScaleKey = "kNativeScaleKey"
//let kShowRecentGamesKey = "kShowRecentGamesKey"
//let kShowRecentSavesKey = "kShowRecentSavesKey"
//let kShowGameBadgesKey = "kShowGameBadgesKey"
//let kTimedAutoSaves = "kTimedAutoSavesKey"
//let kTimedAutoSaveInterval = "kTimedAutoSaveIntervalKey"
//let kICadeControllerSettingKey = "kiCadeControllerSettingKey"
//let kVolumeSettingKey = "kVolumeSettingKey"
//let kFPSCountKey = "kFPSCountKey"
//let kShowGameTitlesKey = "kShowGameTitlesKey"
//let kWebDayAlwwaysOnKey = "kWebDavAlwaysOnKey"
//let kThemeKey = "kThemeKey"
//let kButtonTintsKey = "kButtonsTintsKey"
//let kStartSelectAlwaysOnKey = "kStartSelectAlwaysOnKey"
//let kAllRightShouldersKey = "kAllRightShouldersKey"
//let kVolumeHUDKey = "kVolumeHUDKey"

//let kGameLibraryScaleKey = "kkGameLibraryScaleKey"

//@objc class PVSetting : NSObject, Codable {
//    @objc let defaultValue : NSValue & Codable
//
//    init(_ defaultValue : AnyObject & Codable) {
//        self.defaultValue = defaultValue
//    }
//}

@objcMembers
@objc public final class PVSettingsModel: NSObject {

//    @objc public class DebugOptions : NSObject {
//        @objc public dynamic var iCloudSync = false
//        @objc public dynamic var unsupportedCores = false
//    }

//    @objc public dynamic var debugOptions = DebugOptions()

    @objc public var autoSave = true
    @objc public var timedAutoSaves = true
    @objc public var timedAutoSaveInterval = minutes(10)

    @objc public var askToAutoLoad = true
    @objc public var autoLoadSaves = false

    @objc public var disableAutoLock = false
    @objc public var buttonVibration = true

    @objc public var imageSmoothing = false
    @objc public var crtFilterEnabled = false
    @objc public var nativeScaleEnabled = true

    @objc public var showRecentSaveStates = true
    @objc public var showGameBadges = true
    @objc public var showRecentGames = true

    @objc public var showFPSCount = false

    @objc public var showGameTitles = true
    @objc public var gameLibraryScale = 1.0

    @objc public var webDavAlwaysOn = false
    @objc public var myiCadeControllerSetting = iCadeControllerSetting.disabled

    @objc public var controllerOpacity = 0.8
    @objc public var buttonTints = true
    @objc public var startSelectAlwaysOn = false

    @objc public var allRightShoulders = false

    @objc public var volume = 1.0
    @objc public var volumeHUD = true

    @objc public static let shared = PVSettingsModel()

    override init() {
//        #if os(tvOS) && DEBUG
//        let initialkStartSelectAlwaysOnKey = true
//        #else
//        let initialkStartSelectAlwaysOnKey = false
//        #endif
//
//        UserDefaults.standard.register(defaults: [kAutoSaveKey: true,
//                                                  kTimedAutoSaves: true,
//                                                  kTimedAutoSaveInterval: minutes(10),
//                                                  kAskToAutoLoadKey: true,
//                                                  kAutoLoadSavesKey: false,
//                                                  kControllerOpacityKey: 0.8,
//                                                  kDisableAutoLockKey: false,
//                                                  kButtonVibrationKey: true,
//                                                  kImageSmoothingKey: false,
//                                                  kCRTFilterKey: false,
//                                                  kNativeScaleKey: true,
//                                                  kShowRecentGamesKey: true,
//                                                  kShowRecentSavesKey: true,
//                                                  kShowGameBadgesKey: true,
//                                                  kICadeControllerSettingKey: iCadeControllerSetting.disabled.rawValue,
//                                                  kVolumeSettingKey: 1.0,
//                                                  kFPSCountKey: false,
//                                                  kShowGameTitlesKey: true,
//                                                  kWebDayAlwwaysOnKey: false,
//                                                  kButtonTintsKey: false,
//                                                  kStartSelectAlwaysOnKey: initialkStartSelectAlwaysOnKey,
//                                                  kAllRightShouldersKey: false,
//                                                  kVolumeHUDKey: true,
//                                                  //                                                  kThemeKey: theme,
//                                                  kGameLibraryScaleKey: 1.0 ])

////        UserDefaults.standard.synchronize()
//
//        autoSave = UserDefaults.standard.bool(forKey: kAutoSaveKey)
//        timedAutoSaves = UserDefaults.standard.bool(forKey: kTimedAutoSaves)
//        timedAutoSaveInterval = UserDefaults.standard.double(forKey: kTimedAutoSaveInterval)
//        autoLoadSaves = UserDefaults.standard.bool(forKey: kAutoLoadSavesKey)
//        controllerOpacity = CGFloat(UserDefaults.standard.float(forKey: kControllerOpacityKey))
//        disableAutoLock = UserDefaults.standard.bool(forKey: kDisableAutoLockKey)
//        buttonVibration = UserDefaults.standard.bool(forKey: kButtonVibrationKey)
//        imageSmoothing = UserDefaults.standard.bool(forKey: kImageSmoothingKey)
//        crtFilterEnabled = UserDefaults.standard.bool(forKey: kCRTFilterKey)
//        nativeScaleEnabled = UserDefaults.standard.bool(forKey: kNativeScaleKey)
//        showRecentSaveStates = UserDefaults.standard.bool(forKey: kShowRecentSavesKey)
//        showRecentGames = UserDefaults.standard.bool(forKey: kShowRecentGamesKey)
//        showGameBadges = UserDefaults.standard.bool(forKey: kShowGameBadgesKey)
//        let iCade = UserDefaults.standard.integer(forKey: kICadeControllerSettingKey)
//        myiCadeControllerSetting = iCadeControllerSetting(rawValue: Int(iCade)) ?? iCadeControllerSetting.disabled
//        volume = UserDefaults.standard.float(forKey: kVolumeSettingKey)
//        showFPSCount = UserDefaults.standard.bool(forKey: kFPSCountKey)
//        showGameTitles = UserDefaults.standard.bool(forKey: kShowGameTitlesKey)
//        webDavAlwaysOn = UserDefaults.standard.bool(forKey: kWebDayAlwwaysOnKey)
//        askToAutoLoad = UserDefaults.standard.bool(forKey: kAskToAutoLoadKey)
//        buttonTints = UserDefaults.standard.bool(forKey: kButtonTintsKey)
//        startSelectAlwaysOn = UserDefaults.standard.bool(forKey: kStartSelectAlwaysOnKey)
//        allRightShoulders = UserDefaults.standard.bool(forKey: kAllRightShouldersKey)
//        volumeHUD = UserDefaults.standard.bool(forKey: kVolumeHUDKey)
//        gameLibraryScale = UserDefaults.standard.double(forKey: kGameLibraryScaleKey)

//        #if os(iOS)
//        let themeString = UserDefaults.standard.string(forKey: kThemeKey) ?? Themes.defaultTheme.rawValue
//        self.theme = Themes(rawValue: themeString) ?? Themes.defaultTheme
//        #endif

        super.init()

        for c in Mirror( reflecting: self ).children {
            guard let key = c.label else {
                continue
            }

            self.setValue( UserDefaults.standard.object( forKey: key ), forKey: key )
            self.addObserver( self, forKeyPath: key, options: .new, context: nil )
        }
    }

    deinit {
        for c in Mirror( reflecting: self ).children {
            guard let key = c.label else {
                continue
            }

            self.removeObserver( self, forKeyPath: key )
        }
    }

	@discardableResult
	func toggle(_ key : String) -> Bool {
		guard var value = UserDefaults.standard.object(forKey: key) as? Bool else {
			return false
		}

		value = !value
		UserDefaults.standard.set(value, forKey: key)
		return value
	}
}
