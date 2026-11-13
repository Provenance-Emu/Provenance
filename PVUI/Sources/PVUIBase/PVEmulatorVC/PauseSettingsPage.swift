//
//  PauseSettingsPage.swift
//  PVUI
//
//  App preferences the pause menu's Settings page changes in place. Each takes effect
//  at once (audio, screen lock, volume bar), when the menu closes (status lights) or the
//  next time a game starts (launch save).
//

import Foundation
import PVSettings

/// What happens to the most recent save state when a game starts. The app stores it as
/// two switches (`autoLoadSaves`, `askToAutoLoad`); auto load wins when both are on.
enum PauseLaunchSaveMode: String, CaseIterable, Sendable {
    case resume, ask, off

    init(autoLoad: Bool, ask: Bool) {
        self = autoLoad ? .resume : (ask ? .ask : .off)
    }

    /// The two stored switches for this mode.
    var switches: (autoLoad: Bool, ask: Bool) {
        switch self {
        case .resume: return (true, false)
        case .ask: return (false, true)
        case .off: return (false, false)
        }
    }

    /// The mode a tap moves to.
    var next: PauseLaunchSaveMode {
        switch self {
        case .resume: return .ask
        case .ask: return .off
        case .off: return .resume
        }
    }

    var title: String {
        switch self {
        case .resume: return String(localized: "Resume")
        case .ask: return String(localized: "Ask")
        case .off: return String(localized: "Off")
        }
    }

    static var current: PauseLaunchSaveMode {
        PauseLaunchSaveMode(autoLoad: Defaults[.autoLoadSaves], ask: Defaults[.askToAutoLoad])
    }

    func apply() {
        Defaults[.autoLoadSaves] = switches.autoLoad
        Defaults[.askToAutoLoad] = switches.ask
    }
}

extension PauseTileMenuViewModel {
    static let monoAudioTileID = "monoAudio"
    static let silentModeTileID = "respectSilentMode"
    static let headphonesPauseTileID = "pauseOnHeadphones"
    static let keepAwakeTileID = "keepScreenAwake"
    static let screenshotsToPhotosTileID = "screenshotsToPhotos"
    static let volumeHUDTileID = "volumeHUD"
    static let statusLightsTileID = "statusLights"
    static let launchSaveTileID = "launchSave"
    static let launchSaveOptionPrefix = "launchSave_"

    /// The switches for these preferences, in the order the page shows them.
    static func preferenceCells() -> [PauseMenuTile] {
        var cells: [PauseMenuTile] = [
            switchCell(id: monoAudioTileID, isOn: Defaults[.monoAudio], icon: "speaker.wave.1",
                       label: String(localized: "Mono Audio"),
                       description: String(localized: "Mix both channels into one, for one earbud or one speaker."))
        ]
        #if os(iOS)
        cells.append(switchCell(
            id: silentModeTileID, isOn: Defaults[.respectMuteSwitch], icon: "bell.slash",
            label: String(localized: "Respect Silent Mode"),
            description: String(localized: "Silence the game when the ringer is off. Headphones still play.")))
        #endif
        cells.append(switchCell(
            id: headphonesPauseTileID, isOn: Defaults[.pauseOnHeadphonesDisconnect],
            icon: "headphones", label: String(localized: "Pause on Unplug"),
            description: String(localized: "Pause when AirPods or Bluetooth headphones disconnect.")))
        #if os(iOS) && !targetEnvironment(macCatalyst)
        cells.append(switchCell(
            id: volumeHUDTileID, isOn: Defaults[.volumeHUD], icon: "speaker.wave.2.circle",
            label: String(localized: "Volume HUD"),
            description: String(localized: "Show a slim volume bar instead of the system volume overlay.")))
        #endif
        cells.append(launchSaveCell(mode: .current))
        cells.append(switchCell(id: keepAwakeTileID, isOn: Defaults[.disableAutoLock], icon: "sun.max",
                                label: String(localized: "Keep Screen On"),
                                description: String(localized: "Stop the screen dimming and locking while you play.")))
        cells.append(switchCell(
            id: statusLightsTileID, isOn: Defaults[.showStatusIndicators], icon: "circle.grid.2x1.fill",
            label: String(localized: "Status Lights"),
            description: String(localized: "Show small lights for JIT, netplay and more once the menu closes.")))
        #if os(iOS)
        cells.append(switchCell(id: screenshotsToPhotosTileID, isOn: Defaults[.saveScreenshotsToPhotoLibrary],
                                icon: "photo.badge.plus", label: String(localized: "Screenshots to Photos"),
                                description: String(localized: "Also save each screenshot to the Photos library.")))
        #endif
        return cells
    }

    /// The setting a switch cell flips, or nil when `id` is not one of them.
    static func preferenceKey(forCellID id: String) -> Defaults.Key<Bool>? {
        switch id {
        case monoAudioTileID: return .monoAudio
        case silentModeTileID: return .respectMuteSwitch
        case headphonesPauseTileID: return .pauseOnHeadphonesDisconnect
        case keepAwakeTileID: return .disableAutoLock
        case screenshotsToPhotosTileID: return .saveScreenshotsToPhotoLibrary
        case volumeHUDTileID: return .volumeHUD
        case statusLightsTileID: return .showStatusIndicators
        default: return nil
        }
    }

    /// The save to load at launch: tap steps through the modes, long-press picks one.
    static func launchSaveCell(mode: PauseLaunchSaveMode) -> PauseMenuTile {
        PauseMenuTile(
            id: launchSaveTileID,
            icon: mode == .off ? "power" : "clock.arrow.circlepath",
            label: String(localized: "Load Save at Launch"),
            badge: mode == .off ? "OFF" : mode.title,
            description: String(localized: "Resume from the latest save, ask each time, or always start fresh."),
            colorKey: mode == .off ? .gray : .teal,
            dismissOnTap: false,
            longPressOptions: PauseLaunchSaveMode.allCases.map {
                PauseMenuTileLongPressOption(id: launchSaveOptionPrefix + $0.rawValue, title: $0.title,
                                             isSelected: $0 == mode)
            }
        )
    }

    private static func switchCell(id: String, isOn: Bool, icon: String, label: String,
                                   description: String) -> PauseMenuTile {
        PauseMenuTile(id: id, icon: icon, label: label, badge: isOn ? "ON" : "OFF", description: description,
                      colorKey: isOn ? .green : .gray, dismissOnTap: false)
    }
}
