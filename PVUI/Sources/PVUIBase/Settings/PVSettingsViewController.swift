//  PVSettingsViewController.swift
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#if canImport(SafariServices)
import SafariServices
#endif
import PVLibrary
import PVSupport
import PVLogging

import Reachability
import RealmSwift
#if canImport(UIKit)
import UIKit
#endif
import RxSwift

import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings
import Combine

#if canImport(PVWebServer)
import PVWebServer
#endif

fileprivate var IsAppStore: Bool {
    Bundle.main.infoDictionary?["ALTDeviceID"] != nil
}

public final class PVSettingsViewController: QuickTableViewController {
    // Check to see if we are connected to WiFi. Cannot continue otherwise.
    let reachability: Reachability = try! Reachability()

    private var cancellables = Set<AnyCancellable>()

    public var conflictsController: PVGameLibraryUpdatesController? {
        didSet {
            setupConflictsObserver()
        }
    }
    private var numberOfConflicts = 0

    private func setupConflictsObserver() {
        conflictsController?.$conflicts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conflicts in
                self?.numberOfConflicts = conflicts.count
                self?.generateTableViewViewModels()
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }


    public override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.title = "Settings"
        generateTableViewViewModels()
        tableView.reloadData()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        splitViewController?.title = "Settings"
        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }

#if os(tvOS)
        tableView.rowHeight = UITableView.automaticDimension
        splitViewController?.view.backgroundColor = .black
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.backgroundColor =  UIColor.black.withAlphaComponent(0.8)
#else
        let palette = ThemeManager.shared.currentPalette
        if palette.dark {
            tableView.backgroundColor = palette.settingsCellBackground?.subtractBrightness(0.1)
        } else {
            tableView.backgroundColor = palette.settingsCellBackground?.addBrightness(0.1)
        }
#endif
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        reachability.stopNotifier()
    }

#if os(tvOS)
    private var heightDictionary: [IndexPath: CGFloat] = [:]

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        heightDictionary[indexPath] = cell.frame.size.height
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        let height = heightDictionary[indexPath]
        return height ?? UITableView.automaticDimension
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.regular)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.regular)
        cell.layer.cornerRadius = 12
        return cell
    }
#endif

    @MainActor
    func generateTableViewViewModels() {
        typealias TableRow = Row & RowStyle

        // MARK: -- Section : App
        let systemsRow = SegueNavigationRow(text: NSLocalizedString("Systems", comment: "Systems"), detailText: .subtitle("Information on cores, their bioses, links and stats."), icon: .sfSymbol("square.stack"), viewController: self, segue: "pushSystemSettings")
        let systemMode = self.traitCollection.userInterfaceStyle == .dark ? "Dark" : "Light"
        let currentPalette = Defaults[.theme]
        DLOG("Current theme from Defaults: \(currentPalette)")
        var themeDescription = currentPalette.description
        if case .standard(.auto) = currentPalette {
            themeDescription += " (\(systemMode))"
        }

        let themeRow = NavigationRow(text: NSLocalizedString("Theme", comment: "Theme"), detailText: .value1(themeDescription), icon: .sfSymbol("paintbrush"), action: { row in
            let alert = UIAlertController(title: "Theme", message: "", preferredStyle: .actionSheet)
            alert.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
            alert.popoverPresentationController?.sourceView = self.tableView
            alert.popoverPresentationController?.sourceRect = self.tableView.bounds

            // Standard themes
            ThemeOptionsStandard.allCases.forEach { mode in
                let modeLabel = mode == .auto ? mode.description + " (\(systemMode))" : mode.description
                let action = UIAlertAction(title: modeLabel, style: .default, handler: { _ in
                    Task { @MainActor in
                        let darkTheme = (mode == .auto && self.traitCollection.userInterfaceStyle == .dark) || mode == .dark
                        let newTheme = darkTheme ? ProvenanceThemes.dark.palette : ProvenanceThemes.light.palette
                        ThemeManager.shared.setCurrentPalette(newTheme)
                        UIApplication.shared.windows.first?.overrideUserInterfaceStyle = darkTheme ? .dark : .light

                        Defaults[.theme] = .standard(mode)
                        DLOG("Saving theme to Defaults: .standard(\(mode))")


                        // Apply the theme again, hacky
                        ThemeManager.applySavedTheme()

                        self.generateTableViewViewModels()
                    }
                })
                alert.addAction(action)
            }

            // CGA themes
            CGAThemes.allCases.forEach { cgaTheme in
                let action = UIAlertAction(title: cgaTheme.palette.name, style: .default, handler: { _ in
                    Task { @MainActor in
                        let palette = cgaTheme.palette
                        ThemeManager.shared.setCurrentPalette(palette)
                        UIApplication.shared.windows.first!.overrideUserInterfaceStyle = palette.dark ? .dark : .light

                        // Convert CGAThemes to ThemeOptionsCGA
                        let themeOptionCGA = ThemeOptionsCGA(rawValue: cgaTheme.rawValue) ?? .blue
                        Defaults[.theme] = .cga(themeOptionCGA)
                        DLOG("Saving theme to Defaults: .cga(\(themeOptionCGA))")

                        // Add a verification step
                        let savedTheme = Defaults[.theme]
                        DLOG("Verified saved theme in Defaults: \(savedTheme)")

                        // Apply the theme again, hacky
                        ThemeManager.applySavedTheme()

                        self.generateTableViewViewModels()
                    }
                })
                alert.addAction(action)
            }

            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: { _ in
                if let indexPathForSelectedRow = self.tableView.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: indexPathForSelectedRow, animated: false)
                }
            }))
            self.present(alert, animated: true)
        })

#if os(tvOS)
        let appRows: [TableRow] = [systemsRow]
#else
        let autolockRow = PVSettingsSwitchRow(text: NSLocalizedString("Disable Auto Lock", comment: "Disable Auto Lock"), detailText: .subtitle("This also disables the screensaver."), key: .disableAutoLock, icon: .sfSymbol("powersleep"))
        let appRows: [TableRow] = [autolockRow, systemsRow, themeRow]
#endif

        let appSection = Section(title: NSLocalizedString("App", comment: "App"), rows: appRows)

        // MARK: -- Core Options
        // Extra Info Section
        let coreOptionsRows: [TableRow] = [
            SegueNavigationRow(text: NSLocalizedString("Core Options", comment: "Core Options"),
                               detailText: .subtitle("Additional options for the cores."),
                               icon: .sfSymbol("gearshape.2"),
                               viewController: self,
                               segue: "coreOptionsSegue",
                               customization: nil),
        ]

        let coreOptionsSection = Section(title: nil, rows: coreOptionsRows)

        // MARK: -- Section : Saves
        var saveRows: [TableRow] = [
            PVSettingsSwitchRow(text: NSLocalizedString("Auto Save", comment: "Auto Save"), detailText: .subtitle("Auto-save game state on close. Must be playing for 30 seconds more."), key: .autoSave, icon: .sfSymbol("autostartstop")),
            PVSettingsSwitchRow(text: NSLocalizedString("Timed Auto Saves", comment: "Timed Auto Saves"), detailText: .subtitle("Periodically create save states while you play."), key: .timedAutoSaves, icon: .sfSymbol("clock.badge")),
            PVSettingsSwitchRow(text: NSLocalizedString("Auto Load Saves", comment: "Auto Load Saves"), detailText: .subtitle("Automatically load the last save of a game if one exists. Disables the load prompt."), key: .autoLoadSaves, icon: .sfSymbol("autostartstop.trianglebadge.exclamationmark")),
            PVSettingsSwitchRow(text: NSLocalizedString("Ask to Load Saves", comment: "Ask to Load Saves"), detailText: .subtitle("Prompt to load last save if one exists. Off always boots from BIOS unless auto load saves is active."), key: .askToAutoLoad, icon: .sfSymbol("autostartstop.trianglebadge.exclamationmark"))
        ]
#if os(iOS)
        let autoSaveTimeRow = PVSettingsSliderRow(text: NSLocalizedString("Auto-save Time", comment: "Auto-save Time"),
                                                  detailText: .subtitle("Number of minutes between timed auto saves."),
                                                  valueLimits: (min: 1.0, max: 30.0),
                                                  valueImages: (.sfSymbol("hare"), .sfSymbol("tortoise")),
                                                  key: .timedAutoSaveInterval)
        saveRows.append(autoSaveTimeRow)
#endif

        let savesSection = Section(title: NSLocalizedString("Saves", comment: "Saves"), rows: saveRows)

        // MARK: -- Section : Audio/Video
        var avRows = [TableRow]()

#if os(iOS)
        let volumeHudRow: PVSettingsSwitchRow = PVSettingsSwitchRow(text: NSLocalizedString("Volume HUD", comment: "Volume HUD"),
                                                                    key: .volumeHUD,
                                                                    icon: .sfSymbol("speaker.square"))
        avRows.append(volumeHudRow)
        let volumeRow: PVSettingsSliderRow = PVSettingsSliderRow(text: NSLocalizedString("Volume", comment: "Volume"),
                                                                 detailText: nil,
                                                                 valueLimits: (min: 0.0, max: 1.0),
                                                                 valueImages: (.sfSymbol("speaker.wave.1"), .sfSymbol("speaker.wave.3")),
                                                                 key: .volume)
        avRows.append(volumeRow)
#endif
        avRows.append(contentsOf: [
            PVSettingsSwitchRow(text: NSLocalizedString("Multi-threaded GL", comment: "Multi-threaded GL"),
                                detailText: .subtitle("Use iOS's EAGLContext multiThreaded. May improve or slow down GL performance."),
                                key: .multiThreadedGL,
                                icon: .sfSymbol("rectangle.split.3x3")),
            PVSettingsSwitchRow(text: NSLocalizedString("4X Multisampling GL", comment: "4X Multisampling GL"),
                                detailText: .subtitle("Use iOS's EAGLContext multisampling. Slower speed (slightly), smoother edges."),
                                key: .multiSampling,
                                icon: .sfSymbol("4k.tv")),
            PVSettingsSwitchRow(text: NSLocalizedString("Native Scale", comment: "Native Scale"),
                                detailText: .subtitle("Scale up to fit native screen resolution."),
                                key: .nativeScaleEnabled,
                                icon: .sfSymbol("square.split.bottomrightquarter")),
            PVSettingsSwitchRow(text: NSLocalizedString("Integer Scaling", comment: "Integer Scaling"),
                                detailText: .subtitle("Lock scaling to integer values. Sharper but may result in blank space depending on the original aspect ratio."),
                                key: .integerScaleEnabled,
                                icon: .sfSymbol("lock.square")),
            PVSettingsSwitchRow(text: NSLocalizedString("Image Smoothing", comment: "Image Smoothing"),
                                detailText: .subtitle("Apply native iOS global image anti-aliasing smoothing filter to all emus."),
                                key: .imageSmoothing,
                                icon: .sfSymbol("checkerboard.rectangle")),
            PVSettingsSwitchRow(text: NSLocalizedString("FPS Counter", comment: "FPS Counter"), detailText: .subtitle("Performance overlay with FPS, CPU and Memory stats. Note: FPS may not be accurate for threaded and/or GLES/Vulkan native cores."), key: .showFPSCount, icon: .sfSymbol("speedometer"))
        ])

        let avSection = Section(title: NSLocalizedString("Video Options", comment: "Video Options"), rows: avRows)


        // MARK -- Section : Controller

        var controllerRows = [TableRow]()

#if os(iOS)
        controllerRows.append(PVSettingsSliderRow(text: NSLocalizedString("Opacity", comment: "Opacity"),
                                                  detailText: .subtitle("Transparency amount of on-screen controls overlays."),
                                                  valueLimits: (min: 0.0, max: 1.0),
                                                  valueImages: (.sfSymbol("sun.min"), .sfSymbol("sun.max")),
                                                  key: .controllerOpacity))

        controllerRows.append(contentsOf: [
            PVSettingsSwitchRow(text: NSLocalizedString("Button Colors", comment: "Button Colors"),
                                detailText: .subtitle("Color the on-screen controls to be similar to their original system controller colors where applicable."),
                                key: .buttonTints,
                                icon: .sfSymbol("paintpalette")),
            PVSettingsSwitchRow(text: NSLocalizedString("All-Right Shoulders", comment: "All-Right Shoulders"),
                                detailText: .subtitle("Moves L1, L2 & Z to right side"),
                                key: .allRightShoulders,
                                icon: .sfSymbol("l.joystick.tilt.right")),
            PVSettingsSwitchRow(text: NSLocalizedString("Haptic Feedback", comment: "Haptic Feedback"),
                                detailText: .subtitle("Vibrate on button push and force feedback on iPhone and controllers where applicable."),
                                key: .buttonVibration,
                                icon: .sfSymbol("hand.point.up.braille")),
            PVSettingsSwitchRow(text: NSLocalizedString("Enable 8BitDo M30 Mapping", comment: "Enable 8BitDo M30 Mapping"),
                                detailText: .subtitle("For use with Sega Genesis/Mega Drive, Sega/Mega CD, 32X, Saturn and the PC Engine."),
                                key: .use8BitdoM30,
                                icon: .sfSymbol("arrow.triangle.swap")),
            PVSettingsSwitchRow(text: NSLocalizedString("Missing Buttons Always On-Screen", comment: "Missing Buttons Always On-Screen"),
                                detailText: .subtitle("Supports: SNES, SMS, SG, GG, SCD, PSX."),
                                key: .missingButtonsAlwaysOn,
                                icon: .sfSymbol("l.rectangle.roundedbottom"))
        ]

        )
#endif
        controllerRows.append(contentsOf: [
            SegueNavigationRow(text: NSLocalizedString("Controllers", comment: "Controllers"), detailText: .subtitle("Assign players"), icon:.sfSymbol("gamecontroller"), viewController: self, segue: "controllersSegue"),
            SegueNavigationRow(text: NSLocalizedString("iCade Controller", comment: "iCade Controller"), detailText: .subtitle(Defaults[.myiCadeControllerSetting].description), icon:.sfSymbol("keyboard"), viewController: self, segue: "iCadeSegue", customization: { cell, _ in
                Task { @MainActor in
                    cell.detailTextLabel?.text = Defaults[.myiCadeControllerSetting].description
                }
            })
        ])
#if os(tvOS)
        controllerRows.append(contentsOf: [
            PVSettingsSwitchRow(text: NSLocalizedString("Enable 8BitDo M30 Mapping", comment: "Enable 8BitDo M30 Mapping"), detailText: .subtitle("For use with Sega Genesis/Mega Drive, Sega/Mega CD, 32X, Saturn and the \nTG16/PC Engine, TG16/PC Engine CD and SuperGrafx systems."), key: .use8BitdoM30)
        ])
#endif

        let controllerSection = Section(title: NSLocalizedString("Controllers", comment: "Controllers"), rows: controllerRows, footer: "Check the wiki for controls per systems.")

        // Game Library

#if canImport(PVWebServer)
        var libraryRows: [TableRow] = [
            NavigationRow(
                text: NSLocalizedString("Launch Web Server", comment: "Launch Web Server"),
                detailText: .subtitle("Import/Export ROMs, saves, cover art…"),
                icon: .sfSymbol("xserve"),
                customization: nil,
                action: { [weak self] _ in
                    self?.launchWebServerAction()
                }
            )
        ]
#else
        var libraryRows: [TableRow] = [ ]
#endif

#if os(tvOS)
        let webServerAlwaysOn = PVSettingsSwitchRow(
            text: "Web Server Always-On",
            detailText: .subtitle(""),
            key: .webDavAlwaysOn,
            icon: .sfSymbol("lightswitch.on"),
            customization: { cell, _ in
                DispatchQueue.main.async {
                    if Defaults[.webDavAlwaysOn] {
                        let subTitleText = "WebDAV: \(PVWebServer.shared.webDavURLString)"
                        cell.detailTextLabel?.text = subTitleText
                    } else {
                        cell.detailTextLabel?.text = nil
                    }
                }
            }
        )
        libraryRows.append(webServerAlwaysOn)
#endif

        let librarySection = Section(title: NSLocalizedString("Game Library", comment: "Game Library"), rows: libraryRows, footer: "Check the wiki about importing ROMs.")

        // Game Library 2
        let library2Rows: [TableRow] = [
            NavigationRow(
                text: NSLocalizedString("Re-import all ROMs Directories", comment: ""),
                detailText: .subtitle("Re-import all ROMs from the ROMs Directory"),
                icon: .sfSymbol("triangle.circle.fill"),
                customization: nil,
                action: { [weak self] _ in
                    self?.reimportROMsAction()
                }
            ),
            NavigationRow(
                text: NSLocalizedString("Reset Everything", comment: ""),
                detailText: .subtitle("Delete All Settings, Re-import ROMs ⚠️ Very Slow"),
                icon: .sfSymbol("delete.forward.fill"),
                customization: nil,
                action: { [weak self] _ in
                    self?.resetDataAction()
                }
            ),
            NavigationRow(
                text: NSLocalizedString("Refresh Game Library", comment: ""),
                detailText: .subtitle("Re-import ROMs ⚠️ Slow"),
                icon: .sfSymbol("arrow.uturn.forward"),
                customization: nil,
                action: { [weak self] _ in
                    self?.refreshGameLibraryAction()
                }
            ),
            NavigationRow(
                text: NSLocalizedString("Empty Image Cache", comment: "Empty Image Cache"),
                detailText: .subtitle("Re-download covers"),
                icon: .sfSymbol("trash"),
                customization: nil,
                action: { [weak self] _ in
                    self?.emptyImageCacheAction()
                }
            ),
            NavigationRow(
                text: NSLocalizedString("Manage Conflicts", comment: ""),
                detailText: .subtitle(numberOfConflicts > 0 ? "Manually resolve conflicted imports: \(numberOfConflicts) detected" : "None detected"),
                icon: .sfSymbol("bandage"),
                action: numberOfConflicts > 0 ? { [weak self] _ in self?.manageConflictsAction() } : nil
            ),
            SegueNavigationRow(text: NSLocalizedString("Appearance", comment: "Appearance"),
                               detailText: .subtitle("Visual options for Game Library"),
                               icon: .sfSymbol("eye"),
                               viewController: self,
                               segue: "appearanceSegue")
        ]

        let librarySection2 = Section(title: nil, rows: library2Rows)

        // Beta options
#if !os(tvOS)

        let appStoreRows: [TableRow] = [
//            PVSettingsSwitchRow(text: NSLocalizedString("Advanced Importer", comment: "Advanced Importer"),
//                                detailText: .subtitle("Use larger database for looking up games. Requires an additional 330MB of disk space."),
//                                key: .useMetal, icon: .sfSymbol("sparkle.magnifyingglass")),

            PVSettingsSwitchRow(text: NSLocalizedString("Use Metal", comment: "Use Metal"),
                                detailText: .subtitle("Use newer Metal backend instead of OpenGL. Some cores may experience color or size issues with this mode."),
                                key: .useMetal, icon: .sfSymbol("m.square.fill")),

            PVSettingsSegmentedRow<MainUIMode>(text: NSLocalizedString("UI Mode", comment: "UI Mode"),
                                detailText: .subtitle("Choose between different UI modes."),
                                key: .mainUIMode, icon: .sfSymbol("switch.2"), viewController: self) { cell, row in
                                    cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
                                    if let segmentedControl = cell.accessoryView as? UISegmentedControl {
                                        segmentedControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 12)], for: .normal)
                                    }
                                },
            
            PVSettingsSegmentedRow<SkinMode>(text: NSLocalizedString("Controller Skin Mode", comment: "Controller Skin Mode"),
                                detailText: .subtitle("Choose between different on-screen controller skin modes."),
                                             key: .skinMode, icon: .sfSymbol("switch.2"), viewController: self) { cell, row in
                                    cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
                                    if let segmentedControl = cell.accessoryView as? UISegmentedControl {
                                        segmentedControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 12)], for: .normal)
                                    }
                                },

//            PVSettingsSwitchRow(text: NSLocalizedString("Use Legacy Audio Engine", comment: "Use Legacy Audio Engine"),
//                                detailText: .subtitle("Use the older CoreAudio audio engine instead of AVAudioEngine"),
//                                key: .useLegacyAudioEngine, icon: .sfSymbol("waveform")),
//
//            PVSettingsSwitchRow(text: NSLocalizedString("Mono Audio", comment: "Mono Audio"),
//                                detailText: .subtitle("Mix all audio in mono. The Legacy Audio Engine is not supported."),
//                                key: .monoAudio, icon: .sfSymbol("ear.badge.waveform")),

//            PVSettingsSwitchRow(text: NSLocalizedString("iCloud Sync", comment: "iCloud Sync"),
//                                detailText: .subtitle("Sync core & battery saves, screenshots and BIOS's to iCloud."),
//                                key: .iCloudSync, icon: .sfSymbol("icloud")),

            PVSettingsSwitchRow(text: NSLocalizedString("Movable Buttons", comment: "Bool option to allow user to move on screen controller buttons"),
                                detailText: .subtitle("Allow user to move on screen controller buttons. Tap with 3-fingers 3 times to toggle."),
                                key: .movableButtons, icon: .sfSymbol("arrow.up.and.down.and.arrow.left.and.right")),

            PVSettingsSwitchRow(text: NSLocalizedString("On screen Joypad", comment: ""),
                                detailText: .subtitle("Show a touch Joystick pad on supported systems."),
                                key: .onscreenJoypad, icon: .sfSymbol("l.joystick.tilt.left.fill")),

            PVSettingsSwitchRow(text: NSLocalizedString("On screen Joypad with keyboard", comment: ""),
                                detailText: .subtitle("Show a touch Joystick pad on supported systems when the P1 controller is 'Keyboard'. Useful on iPad OS for systems with an analog joystick (N64, PSX, etc.)"),
                                key: .onscreenJoypadWithKeyboard, icon: .sfSymbol("keyboard.badge.eye"))
        ]

        let nonAppStoreRows: [TableRow] = [
            PVSettingsSwitchRow(text: NSLocalizedString("Auto JIT", comment: "Auto JIT"),
                                detailText: .subtitle("Attempt to automatically enable Just In Time OS support. Requires ZeroConf VPN to be active. See JITStreamer.com for more info."),
                                key: .autoJIT, icon: .sfSymbol("figure.run")),

            PVSettingsSwitchRow(text: NSLocalizedString("Unsupported Cores", comment: "Unsupported Cores"),
                                detailText: .subtitle("Cores that are in development"),
                                key: .unsupportedCores, icon: .sfSymbol("testtube.2"))
        ]

        let betaRows: [TableRow] = IsAppStore ? appStoreRows : (appStoreRows + nonAppStoreRows)
#else // tvOS
        let betaRows: [TableRow] = [
            PVSettingsSwitchRow(text: NSLocalizedString("Use Metal", comment: "Use Metal"), detailText: .subtitle("Use experimental Metal backend instead of OpenGL. Some cores may experience color or size issues with this mode."),
                                key: .useMetal, icon: .sfSymbol("testtube.2")),
            PVSettingsSwitchRow(text: NSLocalizedString("iCloud Sync", comment: "iCloud Sync"),
                                detailText: .subtitle("Sync core & battery saves, screenshots and BIOS's to iCloud."),
                                key: .iCloudSync, icon: .sfSymbol("icloud")),
            PVSettingsSwitchRow(text: NSLocalizedString("Use SwiftUI", comment: "Use SwiftUI"),
                                detailText: .subtitle("Don't use unless you enjoy empty windows."),
                                key: .multiSampling, icon: .sfSymbol("swift")),

            PVSettingsSwitchRow(text: NSLocalizedString("Use Themes", comment: "Use Themes"),
                                detailText: .subtitle("Use iOS themes on tvOS"),
                                key: .tvOSThemes, icon: .sfSymbol("tshirt"))
        ]
#endif

        let betaSection = Section(
            title: NSLocalizedString("Advanced Features", comment: ""),
            rows: betaRows,
            footer: "Additional features for power users."
        )

        // - Social links
        let discordRow = NavigationRow(
            text: NSLocalizedString("Discord", comment: ""),
            detailText: .subtitle("Join our Discord server for help and community chat."),
            icon: .named("discord", in: PVUIBase.BundleLoader.myBundle),
            customization: { cell, row in
                guard let detailTextLabel = cell.detailTextLabel else {  return }
                detailTextLabel.numberOfLines = 0
            },
            action: { _ in
                if let url = URL(string: "https://discord.gg/4TK7PU5") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    self.tableView.deselectRow(at: self.tableView.indexPathForSelectedRow!, animated: false)
                }
            }
        )
        let xRow = NavigationRow(
            text: NSLocalizedString("X", comment: ""),
            detailText: .subtitle("Follow us on X for release and other announcements."),
            icon: .named("x", in: PVUIBase.BundleLoader.myBundle),
            customization: { cell, row in
                guard let detailTextLabel = cell.detailTextLabel else {  return }
                detailTextLabel.numberOfLines = 0
            },
            action: { _ in
                if let url = URL(string: "https://twitter.com/provenanceapp") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    self.tableView.deselectRow(at: self.tableView.indexPathForSelectedRow!, animated: false)
                }
            }
        )
        let githubRow = NavigationRow(
            text: NSLocalizedString("GitHub", comment: ""),
            detailText: .subtitle("Check out GitHub for code, reporting bugs and contributing."),
            icon: .named("github", in: PVUIBase.BundleLoader.myBundle),
            customization: { cell, row in
                guard let detailTextLabel = cell.detailTextLabel else {  return }
                detailTextLabel.numberOfLines = 0
            },
            action: { _ in
                if let url = URL(string: "https://github.com/Provenance-Emu/Provenance") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    self.tableView.deselectRow(at: self.tableView.indexPathForSelectedRow!, animated: false)
                }
            }
        )

#if APP_STORE
        let patreonText = "Support us on Patreon."
#else
        let patreonText = "Support us on Patreon and receive special features and early access builds."
#endif
        let patreonRow = NavigationRow(
            text: NSLocalizedString("Patreon", comment: ""),
            detailText: .subtitle(patreonText),
            icon: .named("patreon", in: PVUIBase.BundleLoader.myBundle),
            customization: { cell, row in
                guard let detailTextLabel = cell.detailTextLabel else {  return }
                detailTextLabel.numberOfLines = 0
            },
            action: { _ in
                if let url = URL(string: "https://provenance-emu.com/patreon") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    self.tableView.deselectRow(at: self.tableView.indexPathForSelectedRow!, animated: false)
                }
            }
        )
        let youTubeRow = NavigationRow(
            text: NSLocalizedString("YouTube", comment: ""),
            detailText: .subtitle("Help tutorial videos and new feature previews."),
            icon: .named("youtube", in: PVUIBase.BundleLoader.myBundle),
            customization: { cell, row in
                guard let detailTextLabel = cell.detailTextLabel else {  return }
                detailTextLabel.numberOfLines = 0
            },
            action: { _ in
                if let url = URL(string: "https://www.youtube.com/channel/UCKeN6unYKdayfgLWulXgB1w") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    self.tableView.deselectRow(at: self.tableView.indexPathForSelectedRow!, animated: false)
                }
            }
        )
        let blogRow = NavigationRow(
            text: NSLocalizedString("Blog", comment: ""),
            detailText: .subtitle("Release announcements and full changelogs and screenshots posted to our blog."),
            icon: .sfSymbol("square.and.pencil"),
            customization: { cell, row in
                guard let detailTextLabel = cell.detailTextLabel else {  return }
                detailTextLabel.numberOfLines = 0
            },
            action: { [weak self] _ in
                if let url = URL(string: "https://provenance-emu.com/blog/") {
#if canImport(SafariServices)
                    let webVC = WebkitViewController(url: url)
                    self?.navigationController?.pushViewController(webVC, animated: true)
#else
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
#endif
                }
            }
        )
        let faqRow = NavigationRow(
            text: NSLocalizedString("FAQ", comment: ""),
            detailText: .subtitle("Frequently asked questions."),
            icon: .sfSymbol("questionmark.folder.fill"),
            customization: { cell, row in
                guard let detailTextLabel = cell.detailTextLabel else {  return }
                detailTextLabel.numberOfLines = 0
            },
            action: { [weak self] _ in
                if let url = URL(string: "https://wiki.provenance-emu.com/faqs") {
#if canImport(SafariServices)
                    let webVC = WebkitViewController(url: url)
                    self?.navigationController?.pushViewController(webVC, animated: true)
#else
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
#endif
                }
            }
        )
        let wikiRow = NavigationRow(
            text: NSLocalizedString("Wiki", comment: ""),
            detailText: .subtitle("Full usage documentation, tips and tricks on our Wiki."),
            icon: .sfSymbol("books.vertical.fill"),
            customization: { cell, row in
                guard let detailTextLabel = cell.detailTextLabel else {  return }
                detailTextLabel.numberOfLines = 0
            },
            action: { [weak self] _ in
                if let url = URL(string: "https://wiki.provenance-emu.com/") {
#if canImport(SafariServices)
                    let webVC = WebkitViewController(url: url)
                    self?.navigationController?.pushViewController(webVC, animated: true)
#else
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
#endif
                }
            }
        )

        let socialLinksRows = [patreonRow, discordRow, xRow, youTubeRow, githubRow]
        let socialLinksSection = Section(title: NSLocalizedString("Socials", comment: ""), rows: socialLinksRows)

        let documentationLinksRow = [blogRow, faqRow, wikiRow]
        let documentationSection = Section(title: NSLocalizedString("Documentation", comment: ""), rows: documentationLinksRow)

        // - Build Information

        let modeLabel = BuildEnvironment.config.uppercased()

        // Note: If you get an error here, run the build again.
        // Blame Swift PM / XCode @JoeMatt
        let gitInfo: PackageBuild = PackageBuild.info

        let branchName = gitInfo.branch?.lowercased() ?? "Unknown"
        let masterBranch: Bool = branchName == "master" || branchName.starts(with: "release")
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        if !masterBranch {
            if IsAppStore {
                versionText = "\(versionText ?? "") AppStore"
            } else {
                versionText = "\(versionText ?? "") Beta"
            }
            //            versionLabel.textColor = UIColor.init(hex: "#F5F5A0")
        }

        // Git Revision (branch/hash)
        var revisionString = NSLocalizedString("Unknown", comment: "")
        if var bundleRevision = Bundle.main.infoDictionary?["Revision"] as? String, !revisionString.isEmpty {
            if !masterBranch {
                bundleRevision = "\(branchName)/\(bundleRevision)"
            }
            revisionString = bundleRevision
        }

        // Build date string
        let incomingDateFormatter = DateFormatter()
        incomingDateFormatter.dateFormat = "E MMM d HH:mm:ss yyyy"

        let outputDateFormatter = DateFormatter()
        outputDateFormatter.dateFormat = "MM/dd/yyyy hh:mm a"

        let buildDate = gitInfo.timeStamp
        let buildDateString: String = outputDateFormatter.string(from: buildDate)

        let builtByUser = BuildEnvironment.userName

        let buildInformationRows: [TableRow] = [
            NavigationRow(
                text: NSLocalizedString("Version", comment: ""),
                detailText: .value2(versionText ?? NSLocalizedString("Unknown", comment: "")),
                icon: nil,
                customization: { cell, _ in
                    if !masterBranch {
                        cell.detailTextLabel?.textColor = .systemYellow
                    }
                },
                action: nil
            ),
            NavigationRow(text: NSLocalizedString("Build", comment: "Build"), detailText: .value2(bundleVersion)),
            NavigationRow(text: NSLocalizedString("Mode", comment: "Mode"), detailText: .value2(modeLabel)),
            NavigationRow(text: NSLocalizedString("Git Revision", comment: "Git Revision"), detailText: .value2(revisionString)),
            NavigationRow(text: NSLocalizedString("Build Date", comment: "Build Date"), detailText: .value2(buildDateString)),
            NavigationRow(text: NSLocalizedString("Builder", comment: "Builder"), detailText: .value2(builtByUser)),
            NavigationRow(text: NSLocalizedString("Bundle ID", comment: "Bundle ID"), detailText: .value2(Bundle.main.bundleIdentifier ?? "Unknown"))
        ]

        let buildSection = Section(title: NSLocalizedString("Build Information", comment: ""), rows: buildInformationRows)

        // Extra Info Section
        let extraInfoRows: [TableRow] = [
            SegueNavigationRow(text: NSLocalizedString("Cores", comment: "Cores"),
                               detailText: .subtitle("Emulator cores provided by these projects."),
                               icon: .sfSymbol("square.3.layers.3d.middle.filled"),
                               viewController: self,
                               segue: "coresSegue",
                               customization: nil),
            SegueNavigationRow(text: NSLocalizedString("Licenses", comment: "Licenses"),
                               detailText: .subtitle("Open-source libraries Provenance uses and their respective licenses."),
                               icon: .sfSymbol("mail.stack.fill"),
                               viewController: self,
                               segue: "licensesSegue",
                               customization: nil)
        ]

        let extraInfoSection = Section(title: NSLocalizedString("3rd Party & Legal", comment: ""), rows: extraInfoRows)

        // Debug section
        //        let debugRows: [TableRow] = [
        //            NavigationRow(text: NSLocalizedString("Logs", comment: "Logs"),
        //                                              detailText: .subtitle("Live logging information"),
        //                                              icon: nil,
        //                                              customization: nil,
        //                                              action: { _ in
        //                                                  self.logsActions()
        //                                              })
        //        ]
        //
        //        let debugSection = Section(title: NSLocalizedString("Debug", comment: ""),
        //                                   rows: debugRows)

        // Set table data
        tableContents = [appSection, coreOptionsSection, savesSection, avSection, controllerSection, librarySection, librarySection2, betaSection, socialLinksSection, documentationSection, buildSection, extraInfoSection]
        //        #if os(iOS)
        //            tableContents.append(debugSection)
        //        #endif
    }

#if canImport(PVWebServer)
    func launchWebServerAction() {
        if reachability.connection == .wifi {
            // connected via wifi, let's continue
            // start web transfer service
            if PVWebServer.shared.startServers() {
                // show alert view
                showServerActiveAlert(sender: self.tableView, barButtonItem: nil)
            } else {
                // Display error
                let alert = UIAlertController(title: "Unable to start web server!",
                                              message: "Check your network connection or settings and free up ports: 80, 81.",
                                              preferredStyle: .alert)
                alert.popoverPresentationController?.sourceView = tableView
                alert.popoverPresentationController?.sourceRect = tableView.bounds
                alert.preferredContentSize = CGSize(width: 500, height: 150)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
                }))
                present(alert, animated: true) { () -> Void in }
            }
        } else {
            let alert = UIAlertController(title: "Unable to start web server!",
                                          message: "Your device needs to be connected to a Wi-Fi network to continue!",
                                          preferredStyle: .alert)
            alert.popoverPresentationController?.sourceView = tableView
            alert.popoverPresentationController?.sourceRect = tableView.bounds
            alert.preferredContentSize = CGSize(width: 500, height: 150)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) { () -> Void in }
        }
    }
#endif

    func reimportROMsAction() {
        tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
        let alert = UIAlertController(title: "Re-Scan all ROM Directories?",
                                      message: """
                                        Attempt scan all ROM Directories,
                                        import all new ROMs found, and update existing ROMs
                                      """,
                                      preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.sourceRect = tableView.bounds
        alert.preferredContentSize = CGSize(width: 500, height: 300)
        alert.addAction(UIAlertAction(title: "Yes",
                                      style: .default,
                                      handler: { (_: UIAlertAction) -> Void in
            NotificationCenter.default.post(name: NSNotification.Name.PVReimportLibrary, object: nil)
            self.done(self)
        }))
        alert.addAction(UIAlertAction(title: "No",
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true) { () -> Void in }
    }
    func resetDataAction() {
        tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
        let alert = UIAlertController(title: "Reset Everything?",
                                      message: """
                                        Attempt to delete all settings / configurations, then
                                        reimport everything.
                                      """,
                                      preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.sourceRect = tableView.bounds
        alert.preferredContentSize = CGSize(width: 500, height: 300)
        alert.addAction(UIAlertAction(title: "Yes",
                                      style: .default,
                                      handler: { (_: UIAlertAction) -> Void in
            NotificationCenter.default.post(name: NSNotification.Name.PVResetLibrary, object: nil)
            self.done(self)
        }))
        alert.addAction(UIAlertAction(title: "No",
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true) { () -> Void in }
    }
    func refreshGameLibraryAction() {
        tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
        let alert = UIAlertController(title: "Refresh Game Library?",
                                      message: """
                                        Attempt to reload the artwork and title
                                        information for your entire library.
                                        This can be a slow process, especially for
                                        large libraries.
                                        Only do this if you really, really want to
                                        try and get more artwork or update the information.
                                      """,
                                      preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.sourceRect = tableView.bounds
        alert.preferredContentSize = CGSize(width: 500, height: 300)
        alert.addAction(UIAlertAction(title: "Yes",
                                      style: .default,
                                      handler: { (_: UIAlertAction) -> Void in
            NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
            self.done(self)
        }))
        alert.addAction(UIAlertAction(title: "No",
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true) { () -> Void in }
    }

    func emptyImageCacheAction() {
        tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
        let alert = UIAlertController(title: NSLocalizedString("Empty Image Cache?", comment: ""),
                                      message: """
                                      Empty the image cache to free up disk space.
                                      Images will be redownloaded on demand.
                                      """,
                                      preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.sourceRect = tableView.bounds
        alert.preferredContentSize = CGSize(width: 500, height: 150)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: ""),
                                      style: .default,
                                      handler: { (_: UIAlertAction) -> Void in
            try? PVMediaCache.empty()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("No", comment: ""),
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true) { () -> Void in }
    }

    func manageConflictsAction() {
        if let conflictsController = conflictsController {
            let conflictViewController = PVConflictViewController(conflictsController: conflictsController)
            navigationController?.pushViewController(conflictViewController, animated: true)
        }
    }

    func logsActions() {
        // Log Viewer
        //        let logViewController = PVLogViewController(nibName: "PVLogViewController", bundle: BundleLoader.module)
        //        logViewController.hideDoneButton()
        //        navigationController?.pushViewController(logViewController, animated: true)
        //        logViewController.hideDoneButton()
    }

    @IBAction func done(_: Any) {
        presentingViewController?.dismiss(animated: true) { () -> Void in }
    }

    @IBAction func help(_: Any) {
#if canImport(SafariServices)
        let webVC = WebkitViewController(url: URL(string: "https://wiki.provenance-emu.com/")!)
        navigationController?.pushViewController(webVC, animated: true)
#endif
    }
}
