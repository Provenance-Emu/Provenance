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
let kAutoLoadAutoSavesKey = "kAutoLoadAutoSavesKey"
let kControllerOpacityKey = "kControllerOpacityKey"
let kAskToAutoLoadKey = "kAskToAutoLoadKey"
let kDisableAutoLockKey = "kDisableAutoLockKey"
let kButtonVibrationKey = "kButtonVibrationKey"
let kImageSmoothingKey = "kImageSmoothingKey"
let kCRTFilterKey = "kCRTFilterKey"
let kShowRecentGamesKey = "kShowRecentGamesKey"
let kICadeControllerSettingKey = "kiCadeControllerSettingKey"
let kVolumeSettingKey = "kVolumeSettingKey"
let kFPSCountKey = "kFPSCountKey"
let kShowGameTitlesKey = "kShowGameTitlesKey"
let kWebDayAlwwaysOnKey = "kWebDavAlwaysOnKey"

class PVSettingsModel: NSObject {
    private var _isAutoSave = false
    var isAutoSave: Bool {
        get {
            return _isAutoSave
        }
        set(autoSave) {
            _isAutoSave = autoSave
            UserDefaults.standard.set(_isAutoSave, forKey: kAutoSaveKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _isAskToAutoLoad = false
    var isAskToAutoLoad: Bool {
        get {
            return _isAskToAutoLoad
        }
        set(askToAutoLoad) {
            _isAskToAutoLoad = askToAutoLoad
            UserDefaults.standard.set(_isAskToAutoLoad, forKey: kAskToAutoLoadKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _isAutoLoadAutoSaves = false
    var isAutoLoadAutoSaves: Bool {
        get {
            return _isAutoLoadAutoSaves
        }
        set(autoLoadAutoSaves) {
            _isAutoLoadAutoSaves = autoLoadAutoSaves
            UserDefaults.standard.set(_isAutoLoadAutoSaves, forKey: kAutoLoadAutoSavesKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _isDisableAutoLock = false
    var isDisableAutoLock: Bool {
        get {
            return _isDisableAutoLock
        }
        set(disableAutoLock) {
            _isDisableAutoLock = disableAutoLock
            UserDefaults.standard.set(_isDisableAutoLock, forKey: kDisableAutoLockKey)
            UserDefaults.standard.synchronize()
            UIApplication.shared.isIdleTimerDisabled = _isDisableAutoLock
        }
    }
    private var _isButtonVibration = false
    var isButtonVibration: Bool {
        get {
            return _isButtonVibration
        }
        set(buttonVibration) {
            _isButtonVibration = buttonVibration
            UserDefaults.standard.set(_isButtonVibration, forKey: kButtonVibrationKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _isImageSmoothing = false
    var isImageSmoothing: Bool {
        get {
            return _isImageSmoothing
        }
        set(imageSmoothing) {
            _isImageSmoothing = imageSmoothing
            UserDefaults.standard.set(_isImageSmoothing, forKey: kImageSmoothingKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _isCrtFilterEnabled = false
    var isCrtFilterEnabled: Bool {
        get {
            return _isCrtFilterEnabled
        }
        set(crtFilterEnabled) {
            _isCrtFilterEnabled = crtFilterEnabled
            UserDefaults.standard.set(_isCrtFilterEnabled, forKey: kCRTFilterKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _isShowRecentGames = false
    var isShowRecentGames: Bool {
        get {
            return _isShowRecentGames
        }
        set(showRecentGames) {
            _isShowRecentGames = showRecentGames
            UserDefaults.standard.set(_isShowRecentGames, forKey: kShowRecentGamesKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _isShowFPSCount = false
    var isShowFPSCount: Bool {
        get {
            return _isShowFPSCount
        }
        set(showFPSCount) {
            _isShowFPSCount = showFPSCount
            UserDefaults.standard.set(_isShowFPSCount, forKey: kFPSCountKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _isShowGameTitles = false
    var isShowGameTitles: Bool {
        get {
            return _isShowGameTitles
        }
        set(showGameTitles) {
            _isShowGameTitles = showGameTitles
            UserDefaults.standard.set(_isShowGameTitles, forKey: kShowGameTitlesKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _isWebDavAlwaysOn = false
    var isWebDavAlwaysOn: Bool {
        get {
            return _isWebDavAlwaysOn
        }
        set(webDavAlwaysOn) {
            _isWebDavAlwaysOn = webDavAlwaysOn
            UserDefaults.standard.set(_isWebDavAlwaysOn, forKey: kWebDayAlwwaysOnKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _iCadeControllerSetting: kICadeControllerSetting?
    var iCadeControllerSetting: kICadeControllerSetting {
        get {
            return _iCadeControllerSetting
        }
        set(iCadeControllerSetting) {
            _iCadeControllerSetting = iCadeControllerSetting
            UserDefaults.standard.set(Int(iCadeControllerSetting), forKey: kICadeControllerSettingKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _controllerOpacity: CGFloat = 0.0
    var controllerOpacity: CGFloat {
        get {
            return _controllerOpacity
        }
        set(controllerOpacity) {
            _controllerOpacity = controllerOpacity
            UserDefaults.standard.set(Float(_controllerOpacity), forKey: kControllerOpacityKey)
            UserDefaults.standard.synchronize()
        }
    }
    private var _volume: Float = 0.0
    var volume: Float {
        get {
            return _volume
        }
        set(volume) {
            _volume = volume
            UserDefaults.standard.set(volume, forKey: kVolumeSettingKey)
        }
    }

    class func sharedInstance() -> PVSettingsModel {
        var _sharedInstance: PVSettingsModel?
        if !_sharedInstance {
            var onceToken: Int
            if (onceToken == 0) {
            /* TODO: move below code to a static variable initializer (dispatch_once is deprecated) */
                _sharedInstance = super.alloc(withZone: nil)()
            }
        onceToken = 1
        }
        return _sharedInstance
    }

    override init() {
        super.init()

        UserDefaults.standard.register(defaults: [kAutoSaveKey: true, kAskToAutoLoadKey: true, kAutoLoadAutoSavesKey: false, kControllerOpacityKey: 0.2, kDisableAutoLockKey: false, kButtonVibrationKey: true, kImageSmoothingKey: false, kCRTFilterKey: false, kShowRecentGamesKey: true, kICadeControllerSettingKey: kICadeControllerSettingDisabled, kVolumeSettingKey: 1.0, kFPSCountKey: false, kShowGameTitlesKey: true, kWebDayAlwwaysOnKey: false])
        UserDefaults.standard.synchronize()
        isAutoSave = UserDefaults.standard.bool(forKey: kAutoSaveKey)
        isAutoLoadAutoSaves = UserDefaults.standard.bool(forKey: kAutoLoadAutoSavesKey)
        controllerOpacity = CGFloat(UserDefaults.standard.float(forKey: kControllerOpacityKey))
        isDisableAutoLock = UserDefaults.standard.bool(forKey: kDisableAutoLockKey)
        isButtonVibration = UserDefaults.standard.bool(forKey: kButtonVibrationKey)
        isImageSmoothing = UserDefaults.standard.bool(forKey: kImageSmoothingKey)
        isCrtFilterEnabled = UserDefaults.standard.bool(forKey: kCRTFilterKey)
        isShowRecentGames = UserDefaults.standard.bool(forKey: kShowRecentGamesKey)
        iCadeControllerSetting = UserDefaults.standard.integer(forKey: kICadeControllerSettingKey)
        volume = UserDefaults.standard.float(forKey: kVolumeSettingKey)
        isShowFPSCount = UserDefaults.standard.bool(forKey: kFPSCountKey)
        isShowGameTitles = UserDefaults.standard.bool(forKey: kShowGameTitlesKey)
        isWebDavAlwaysOn = UserDefaults.standard.bool(forKey: kWebDayAlwwaysOnKey)
    
    }
}