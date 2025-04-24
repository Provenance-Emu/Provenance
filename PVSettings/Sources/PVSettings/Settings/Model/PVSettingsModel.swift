//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVSettingsModel.swift
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import Foundation
@_exported import Defaults

//public typealias Defaults = _Defaults
//public typealias Default = _Default

fileprivate var IsAppStore: Bool {
    Bundle.main.infoDictionary?["ALTDeviceID"] != nil
}

// Video
public
extension Defaults.Keys {
#if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    static let nativeScaleEnabled = Key<Bool>("nativeScaleEnabled", default: true)
#else
    static let nativeScaleEnabled = Key<Bool>("nativeScaleEnabled", default: true)
#endif
    static let imageSmoothing = Key<Bool>("imageSmoothing", default: false)

    static let integerScaleEnabled = Key<Bool>("integerScaleEnabled", default: false)

    static let showRecentSaveStates = Key<Bool>("showRecentSaveStates", default: true)
    static let showGameBadges = Key<Bool>("showGameBadges", default: true)
    
    static let showRecentGames = Key<Bool>("showRecentGames", default: true)
    
    static let showSearchbar = Key<Bool>("showSearchbar", default: true)


    static let showFPSCount = Key<Bool>("showFPSCount", default: false)
    
    static let vsyncEnabled = Key<Bool>("vsyncEnabled", default: true)

}

public
extension Defaults.Keys {
    static let autoSave = Key<Bool>("autoSave", default: true)
    static let timedAutoSaves = Key<Bool>("timedAutoSaves", default: true)
    static let timedAutoSaveInterval = Key<TimeInterval>("timedAutoSaveInterval", default: minutes(10))

    static let askToAutoLoad = Key<Bool>("askToAutoLoad", default: true)
    static let autoLoadSaves = Key<Bool>("autoLoadSaves", default: false)

#if os(tvOS)
    static let disableAutoLock = Key<Bool>("disableAutoLock", default: true)
#else
    static let disableAutoLock = Key<Bool>("disableAutoLock", default: false)
#endif

    static let buttonVibration = Key<Bool>("buttonVibration", default: true)

    static let showGameTitles = Key<Bool>("showGameTitles", default: true)

    static let gameLibraryScale = Key<Float>("gameLibraryScale", default: 4.0)

#if os(tvOS)
    static let webDavAlwaysOn = Key<Bool>("webDavAlwaysOn", default: true)
#else
    static let webDavAlwaysOn = Key<Bool>("webDavAlwaysOn", default: false)
#endif


    static let buttonTints = Key<Bool>("buttonTints", default: true)
    static let use8BitdoM30 = Key<Bool>("use8BitdoM30", default: false)

#if os(tvOS)
    static let missingButtonsAlwaysOn = Key<Bool>("missingButtonsAlwaysOn", default: true)
#else
    static let missingButtonsAlwaysOn = Key<Bool>("missingButtonsAlwaysOn", default: false)
#endif

    static let sort = Key<SortOptions>("sort", default: SortOptions.title)

    static let haveWarnedAboutDebug = Key<Bool>("haveWarnedAboutDebug", default: false)
    static let collapsedSystems = Key<Set<String>>("collapsedSystems", default: [])

    static let collapsedSections = Key<Set<String>>("collapsedSections", default: Set<String>())

#if os(tvOS) || targetEnvironment(macCatalyst)
    static let largeGameArt = Key<Bool>("largeGameArt", default: true)
#endif
}

// MARK: Controls
public extension Defaults.Keys {
#if canImport(UIKit)
    static let myiCadeControllerSetting = Key<iCadeControllerSetting>("myiCadeControllerSetting", default: .disabled)
    static let allRightShoulders = Key<Bool>("allRightShoulders", default: false)
#endif
    static let controllerOpacity = Key<Double>("controllerOpacity", default: 0.8)
    
    static let pauseButtonIsMenuButton = Key<Bool>("pauseButtonIsMenuButton", default: false)
    static let hapticFeedback = Key<Bool>("hapticFeedback", default: true)

    static let buttonPressEffect = Key<ButtonPressEffect>("buttonPressEffect", default: .glow)
    static let buttonSound = Key<ButtonSound>("buttonSound", default: .click)
}

public enum ButtonPressEffect: String, Codable, Equatable, UserDefaultsRepresentable, Defaults.Serializable, CaseIterable {
    case bubble = "bubble"
    case ring = "ring"
    case glow = "glow"

    public var description: String {
        switch self {
        case .bubble:
            return "Bubble + Ring"
        case .ring:
            return "Ring Only"
        case .glow:
            return "Radial Glow"
        }
    }

    public var subtitle: String {
        switch self {
        case .bubble:
            return "Shows both a gradient bubble and ring outline"
        case .ring:
            return "Shows only the ring outline effect"
        case .glow:
            return "Shows a soft radial glow effect"
        }
    }
}

public enum ButtonSound: String, Codable, Equatable, UserDefaultsRepresentable, Defaults.Serializable, CaseIterable {
    case none = "none"
    case generated = "generated"
    case click = "click"
    case tap = "tap"
    case pop = "pop"
    case click2 = "click2"
    case tap2 = "tap2"
    case click3 = "click3"
    case `switch` = "switch"

    public var description: String {
        switch self {
        case .none:
            return "No Sound"
        case .generated:
            return "Generated"
        case .click:
            return "Click"
        case .tap:
            return "Tap"
        case .pop:
            return "Pop"
        case .click2:
            return "Click 2"
        case .tap2:
            return "Tap 2"
        case .click3:
            return "Click 3"
        case .switch:
            return "Switch"
        }
    }

    public var subtitle: String {
        switch self {
        case .none:
            return "Disable button press sounds"
        case .generated:
            return "Classic synthesized tone"
        case .click:
            return "Mechanical click sound"
        case .tap:
            return "Soft tap sound"
        case .pop:
            return "Bubble pop sound"
        case .click2:
            return "Mechanical click sound"
        case .tap2:
            return "Sharp tap sound"
        case .click3:
            return "Thudding click sound"
        case .switch:
            return "Mechaniacal switch sound"
        }
    }

    /// The sound file name in the bundle
    public var filename: String {
        switch self {
        case .none, .generated:
            return ""
        case .click:
            return "button-click"
        case .tap:
            return "button-tap"
        case .pop:
            return "button-pop"
        case .click2:
            return "button-click2"
        case .click3:
            return "button-click3"
        case .tap2:
            return "button-tap2"
        case .switch:
            return "button-switch"
        }
    }
    
    public var hasReleaseSample: Bool {
        switch self {
        case .click, .pop, .switch: return true
        default: return false
        }
    }
}

/// iCloud sync mode for Provenance
public enum iCloudSyncMode: String, Codable, Equatable, UserDefaultsRepresentable, Defaults.Serializable, CaseIterable {
    /// Use iCloud Drive for syncing
    case iCloudDrive = "iCloudDrive"
    
    /// Use CloudKit for syncing
    case cloudKit = "cloudKit"
    
    public var description: String {
        switch self {
        case .iCloudDrive:
            return "iCloud Drive"
        case .cloudKit:
            return "CloudKit"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .iCloudDrive:
            return "Use iCloud Drive for file syncing (legacy)"
        case .cloudKit:
            return "Use CloudKit for database and file syncing (recommended)"
        }
    }
    
    /// Check if CloudKit sync is enabled
    public var isCloudKit: Bool {
        return self == .cloudKit
    }
    
    /// Check if iCloud Drive sync is enabled
    public var isICloudDrive: Bool {
        return self == .iCloudDrive
    }
}

// MARK: File syste
public extension Defaults.Keys {
    static let useAppGroups = Key<Bool>("useAppGroups", default: false)
}

// MARK: Audio Options
public extension Defaults.Keys {
    
    static let volume = Key<Float>("volume", default: 1.0)
    static let volumeHUD = Key<Bool>("volumeHUD", default: true)
    static let audioVisulaizer = Key<Bool>("audioVisulaizer", default: true)

    static let monoAudio = Key<Bool>("monoAudio", default: false)

    static let audioLatency = Key<TimeInterval>("audioLatency", default: 10.0)
    
    static let respectMuteSwitch = Key<Bool>("respectMuteSwitch", default: true)
}

public enum MainUIMode: String, Codable, Equatable, UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, CustomStringConvertible, Identifiable {
    #if !os(tvOS)
    case paged = "Paged"
    #endif
    case singlePage = "Single Page"
    case uikit = "UIKit"
    
    public var id: String {
        rawValue
    }

    public var description: String {
        switch self {
#if !os(tvOS)
        case .paged:
            return "Paged (Default)"
        case .singlePage:
            return "Single Page (RetroWave)"
        case .uikit:
            return "UIKit (Legacy)"
#else
        case .singlePage:
            return "Single Page (RetroWave)"
        case .uikit:
            return "UIKit (Default)"
#endif

        }
    }

    public var subtitle: String {
        switch self {
#if !os(tvOS)
        case .paged:
            return "The default paged mode."
        case .singlePage:
            return "All consoles in a single page, reduced features."
        case .uikit:
            return "Original UIKit mode from 1.X/2.X (Legacy)."
#else
        case .singlePage:
            return "New SwiftUI single page mode."
        case .uikit:
            return "Original UIKit mode."
#endif
        }
    }
}

public enum SkinMode: String, Codable, Equatable, UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, CustomStringConvertible, Identifiable {
    case off = "Off"
    case selectedOnly = "Selected Only"
    case always = "Always"
    
    public var id: String {
        rawValue
    }

    public var description: String {
        switch self {
        case .off:
            return "Off (Classic)"
        case .selectedOnly:
            return "Selected systems only"
        case .always:
            return "Always use"
        }
    }

    public var subtitle: String {
        switch self {
        case .off:
            return "Always use the classic on-screen controller"
        case .selectedOnly:
            return "Use skins for selected sytems, use classic controller as default"
        case .always:
            return "Always use skins including the default generated skins"
        }
    }
}

// MARK: Beta Options
public extension Defaults.Keys {
#if os(macOS) || targetEnvironment(macCatalyst) || os(visionOS)
    static let useMetal = Key<Bool>("useMetal", default: true)
#else
    static let useMetal = Key<Bool>("useMetal", default: true)
#endif
    static let autoJIT = Key<Bool>("autoJIT", default: false)
#if os(tvOS)
    static let mainUIMode = Key<MainUIMode>("mainUIMode", default: .singlePage)
#elseif os(macOS) || targetEnvironment(macCatalyst) || APP_STORE
    static let mainUIMode = Key<MainUIMode>("mainUIMode", default: .paged)
#elseif os(visionOS)
    static let mainUIMode = Key<MainUIMode>("mainUIMode", default: .singlePage)
#else
    static let mainUIMode = Key<MainUIMode>("mainUIMode", default: .paged)
#endif
    static let iCloudSyncMode = Key<iCloudSyncMode>("iCloudSyncMode", default: .cloudKit)
    static let unsupportedCores = Key<Bool>("unsupportedCores", default: false)
    
    /// Legacy setting - kept for backward compatibility
    /// Use iCloudSyncMode instead
    @available(*, deprecated, message: "Use iCloudSyncMode instead")
    static let iCloudSync = Key<Bool>("iCloudSync", default: false)
#if os(tvOS)
    static let tvOSThemes = Key<Bool>("tvOSThemes", default: false)
#endif
#if os(macOS) || targetEnvironment(macCatalyst)
    static let movableButtons = Key<Bool>("movableButtons", default: true)
    static let onscreenJoypad = Key<Bool>("onscreenJoypad", default: false)
    static let onscreenJoypadWithKeyboard = Key<Bool>("onscreenJoypadWithKeyboard", default: false)
#elseif os(iOS)
    static let movableButtons = Key<Bool>("movableButtons", default: true)
    static let onscreenJoypad = Key<Bool>("onscreenJoypad", default: true)
    static let onscreenJoypadWithKeyboard = Key<Bool>("onscreenJoypadWithKeyboard", default: true)
#endif
    
    static let skinMode = Key<SkinMode>("skinMOde", default: .off)
}

// MARK: Video Options
public extension Defaults.Keys {
    static let multiThreadedGL = Key<Bool>("multiThreadedGL", default: true)
    static let multiSampling = Key<Bool>("multiSampling", default: true)
}

// MARK: Objective-C Helper

@objc
@objcMembers
public final class PVSettingsWrapper: NSObject {

    @objc
    public static var use8BitdoM30: Bool {
        get { Defaults[.use8BitdoM30] }
        set { Defaults[.use8BitdoM30] = newValue }}

    @objc
    public static var nativeScaleEnabled: Bool {
        get { Defaults[.nativeScaleEnabled] }
        set { Defaults[.nativeScaleEnabled] = newValue }}

    @objc
    public static var integerScaleEnabled: Bool {
        get { Defaults[.integerScaleEnabled] }
        set { Defaults[.integerScaleEnabled] = newValue }}
    
    @objc
    public static var vsyncEnabled: Bool {
        get { Defaults[.vsyncEnabled] }
        set { Defaults[.vsyncEnabled] = newValue }}

    @objc
    public static var imageSmoothing: Bool {
        get { Defaults[.imageSmoothing] }
        set { Defaults[.imageSmoothing] = newValue }}

    @objc
    public static var volume: Float {
        get { Defaults[.volume] }
        set { Defaults[.volume] = newValue }}
}

public extension Defaults.Keys {
    static let showFavorites = Key<Bool>("showFavorites", default: true)
}
