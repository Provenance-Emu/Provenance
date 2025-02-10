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
#if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    static let nativeScaleEnabled = Key<Bool>("nativeScaleEnabled", default: false)
#else
    static let nativeScaleEnabled = Key<Bool>("nativeScaleEnabled", default: false)
#endif
    static let imageSmoothing = Key<Bool>("imageSmoothing", default: false)

    static let integerScaleEnabled = Key<Bool>("integerScaleEnabled", default: false)

    static let showRecentSaveStates = Key<Bool>("showRecentSaveStates", default: true)
    static let showGameBadges = Key<Bool>("showGameBadges", default: true)
    
    static let showRecentGames = Key<Bool>("showRecentGames", default: true)

    static let showFPSCount = Key<Bool>("showFPSCount", default: false)

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
        }
    }
    
    public var hasReleaseSample: Bool {
        switch self {
        case .click, .pop: return true
        default: return false
        }
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

    static let monoAudio = Key<Bool>("monoAudio", default: false)

    static let audioLatency = Key<TimeInterval>("audioLatency", default: 10.0)
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
    static let useUIKit = Key<Bool>("useUIKit", default: true)
#elseif os(macOS) || targetEnvironment(macCatalyst) || APP_STORE
    static let useUIKit = Key<Bool>("useUIKit", default: false)
#elseif os(visionOS)
    static let useUIKit = Key<Bool>("useUIKit", default: false)
#else
    static let useUIKit = Key<Bool>("useUIKit", default:false)
#endif
    static let iCloudSync = Key<Bool>("iCloudSync", default: false)
    static let unsupportedCores = Key<Bool>("unsupportedCores", default: false)
#if os(tvOS)
    static let tvOSThemes = Key<Bool>("tvOSThemes", default: false)
#endif
#if os(macOS) || targetEnvironment(macCatalyst)
    static let movableButtons = Key<Bool>("movableButtons", default: false)
    static let onscreenJoypad = Key<Bool>("onscreenJoypad", default: false)
    static let onscreenJoypadWithKeyboard = Key<Bool>("onscreenJoypadWithKeyboard", default: false)
#elseif os(iOS)
    static let movableButtons = Key<Bool>("movableButtons", default: false)
    static let onscreenJoypad = Key<Bool>("onscreenJoypad", default: true)
    static let onscreenJoypadWithKeyboard = Key<Bool>("onscreenJoypadWithKeyboard", default: true)
#endif
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
