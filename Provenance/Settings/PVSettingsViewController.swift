//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
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

import Reachability
import RealmSwift
import UIKit
import RxSwift

final class PVSettingsViewController: QuickTableViewController {
    // Check to see if we are connected to WiFi. Cannot continue otherwise.
    let reachability: Reachability = try! Reachability()
    var conflictsController: ConflictsController!
    private var numberOfConflicts = 0
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.title = "Settings"
        generateTableViewViewModels()
        tableView.reloadData()

        #if os(tvOS)
            tableView.rowHeight = UITableView.automaticDimension
            splitViewController?.view.backgroundColor = .black
            navigationController?.navigationBar.isTranslucent = false
            navigationController?.navigationBar.backgroundColor =  UIColor.black.withAlphaComponent(0.8)
        #endif

        conflictsController.conflicts
            .bind(onNext: {
                self.numberOfConflicts = $0.count
                self.generateTableViewViewModels()
                self.tableView.reloadData()
            })
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        splitViewController?.title = "Settings"
        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
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

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.regular)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.regular)
        cell.layer.cornerRadius = 12
        return cell
    }
    #endif

    func generateTableViewViewModels() {
        typealias TableRow = Row & RowStyle

        // -- Section : App
        let systemsRow = SegueNavigationRow(text: NSLocalizedString("Systems", comment: "Systems"), viewController: self, segue: "pushSystemSettings")

        let systemMode = self.traitCollection.userInterfaceStyle == .dark ? "Dark" : "Light"
        var theme = PVSettingsModel.shared.theme.description
        if PVSettingsModel.shared.theme == .auto {
            theme += " (\(systemMode))"
        }
        let themeRow = NavigationRow(text: NSLocalizedString("Theme", comment: "Theme"), detailText: .value1(PVSettingsModel.shared.theme.description), action: { row in
            let alert = UIAlertController(title: "Theme", message: "", preferredStyle: .actionSheet)
            ThemeOptions.themes.forEach { mode in
                let modeLabel = mode == .auto ? mode.description + " (\(systemMode))" : mode.description
                let action = UIAlertAction(title: modeLabel, style: .default, handler: { _ in
                    let darkTheme = (mode == .auto && self.traitCollection.userInterfaceStyle == .dark) || mode == .dark
                    Theme.currentTheme = darkTheme ? Theme.darkTheme : Theme.lightTheme
                    UIApplication.shared.windows.first!.overrideUserInterfaceStyle = darkTheme ? .dark : .light
                    PVSettingsModel.shared.theme = mode

                    self.generateTableViewViewModels()
                })
                alert.addAction(action)
            }
            self.present(alert, animated: true)
        })

        #if os(tvOS)
            let appRows: [TableRow] = [systemsRow]
        #else
            let autolockRow = PVSettingsSwitchRow(text: NSLocalizedString("Disable Auto Lock", comment: "Disable Auto Lock"), detailText: .subtitle("This also disables the screensaver."), key: \PVSettingsModel.disableAutoLock)
            let appRows: [TableRow] = [autolockRow, systemsRow, themeRow]
        #endif

        let appSection = Section(title: NSLocalizedString("App", comment: "App"), rows: appRows)

        // -- Core Options
        let realm = try! Realm()
        let cores: [NavigationRow] = realm.objects(PVCore.self).sorted(byKeyPath: "projectName").compactMap { pvcore in
            guard let coreClass = NSClassFromString(pvcore.principleClass) as? CoreOptional.Type else {
                VLOG("Class <\(pvcore.principleClass)> does not implement CoreOptional")
                return nil
            }

            return NavigationRow(text: pvcore.projectName, detailText: .none, icon: nil, customization: nil, action: { [weak self] row in
                let coreOptionsVC = CoreOptionsViewController(withCore: coreClass)
                coreOptionsVC.title = row.text
                self?.navigationController?.pushViewController(coreOptionsVC, animated: true)
            })
        }

        let coreOptionsSection = Section(title: NSLocalizedString("Core Options", comment: "Core Options"), rows: cores)

        // -- Section : Saves
        let saveRows: [TableRow] = [
            PVSettingsSwitchRow(text: NSLocalizedString("Auto Save", comment: "Auto Save"), key: \PVSettingsModel.autoSave),
            PVSettingsSwitchRow(text: NSLocalizedString("Timed Auto Saves", comment: "Timed Auto Saves"), key: \PVSettingsModel.timedAutoSaves),
            PVSettingsSwitchRow(text: NSLocalizedString("Auto Load Saves", comment: "Auto Load Saves"), key: \PVSettingsModel.autoLoadSaves),
            PVSettingsSwitchRow(text: NSLocalizedString("Ask to Load Saves", comment: "Ask to Load Saves"), key: \PVSettingsModel.askToAutoLoad)
        ]

        let savesSection = Section(title: NSLocalizedString("Saves", comment: "Saves"), rows: saveRows)

        // -- Section : Audio/Video
        var avRows = [TableRow]()

        #if os(iOS)
            avRows.append(contentsOf: [PVSettingsSwitchRow(text: NSLocalizedString("Volume HUD", comment: "Volume HUD"), key: \PVSettingsModel.volumeHUD)])
            avRows.append(PVSettingsSliderRow(text: NSLocalizedString("Volume", comment: "Volume"), detailText: nil, valueLimits: (min: 0.0, max: 1.0), key: \PVSettingsModel.volume))
        #endif
        avRows.append(contentsOf: [
            PVSettingsSwitchRow(text: NSLocalizedString("Native Scale", comment: "Native Scale"), key: \PVSettingsModel.nativeScaleEnabled),
            PVSettingsSwitchRow(text: NSLocalizedString("Integer Scaling", comment: "Integer Scaling"), key: \PVSettingsModel.integerScaleEnabled),
            PVSettingsSwitchRow(text: NSLocalizedString("CRT Filter", comment: "CRT Filter"), key: \PVSettingsModel.crtFilterEnabled),
            PVSettingsSwitchRow(text: NSLocalizedString("LCD Filter", comment: "LCD Filter"), detailText:.subtitle("Use CRT filter on LCD (mobile) screens. LCD filter coming."), key: \PVSettingsModel.lcdFilterEnabled),
            PVSettingsSwitchRow(text: NSLocalizedString("Image Smoothing", comment: "Image Smoothing"), key: \PVSettingsModel.imageSmoothing),
            PVSettingsSwitchRow(text: NSLocalizedString("FPS Counter", comment: "FPS Counter"), key: \PVSettingsModel.showFPSCount)
        ])

        let avSection = Section(title: NSLocalizedString("Video Options", comment: "Video Options"), rows: avRows)

        // Metal Filters
        var shaders: [String] = MetalShaderManager.shared.filterShaders.map { $0.name }
        shaders.insert("Off", at: 0)
        let metalSection = PVSettingsOptionRow(title: NSLocalizedString("Metal Filter", comment: "Metal Filter"),
                                               footer: "Post processing filter when using Metal",
                                               key: \PVSettingsModel.metalFilter,
                                               options: shaders)

        // -- Section : Controler

        var controllerRows = [TableRow]()

        #if os(iOS)
            controllerRows.append(PVSettingsSliderRow(text: NSLocalizedString("Opacity", comment: "Opacity"), detailText: nil, valueLimits: (min: 0.5, max: 1.0), key: \PVSettingsModel.controllerOpacity))

            controllerRows.append(contentsOf: [
                PVSettingsSwitchRow(text: NSLocalizedString("Button Colors", comment: "Button Colors"), key: \PVSettingsModel.buttonTints),
                PVSettingsSwitchRow(text: NSLocalizedString("All-Right Shoulders", comment: "All-Right Shoulders"), detailText: .subtitle("Moves L1, L2 & Z to right side"), key: \PVSettingsModel.allRightShoulders),
                PVSettingsSwitchRow(text: NSLocalizedString("Haptic Feedback", comment: "Haptic Feedback"), key: \PVSettingsModel.buttonVibration),
                PVSettingsSwitchRow(text: NSLocalizedString("Enable 8BitDo M30 Mapping", comment: "Enable 8BitDo M30 Mapping"), detailText: .subtitle("For use with Sega Genesis/Mega Drive, Sega/Mega CD, 32X, Saturn and the PC Engine."), key: \PVSettingsModel.use8BitdoM30)
            ]

        )
        #endif
        controllerRows.append(contentsOf: [
            SegueNavigationRow(text: NSLocalizedString("Controllers", comment: "Controllers"), detailText: .subtitle("Assign players"), viewController: self, segue: "controllersSegue"),
            SegueNavigationRow(text: NSLocalizedString("iCade Controller", comment: "iCade Controller"), detailText: .subtitle(PVSettingsModel.shared.myiCadeControllerSetting.description), viewController: self, segue: "iCadeSegue", customization: { cell, _ in
                cell.detailTextLabel?.text = PVSettingsModel.shared.myiCadeControllerSetting.description
            })
        ])
        #if os(tvOS)
        controllerRows.append(contentsOf: [
            PVSettingsSwitchRow(text: NSLocalizedString("Enable 8BitDo M30 Mapping", comment: "Enable 8BitDo M30 Mapping"), detailText: .subtitle("For use with Sega Genesis/Mega Drive, Sega/Mega CD, 32X, Saturn and the \nTG16/PC Engine, TG16/PC Engine CD and SuperGrafx systems."), key: \PVSettingsModel.use8BitdoM30)
        ])
        #endif

        let controllerSection = Section(title: NSLocalizedString("Controllers", comment: "Controllers"), rows: controllerRows, footer: "Check the wiki for controls per systems.")

        // Game Library

        var libraryRows: [TableRow] = [
            NavigationRow(
                text: NSLocalizedString("Launch Web Server", comment: "Launch Web Server"),
                detailText: .subtitle("Import/Export ROMs, saves, cover art…"),
                icon: nil,
                customization: nil,
                action: { [weak self] _ in
                    self?.launchWebServerAction()
                }
            )
        ]

        #if os(tvOS)
            let webServerAlwaysOn = PVSettingsSwitchRow(
                text: "Web Server Always-On",
                detailText: .subtitle(""),
                key: \PVSettingsModel.webDavAlwaysOn,
                customization: { cell, _ in
                    DispatchQueue.main.async {
                        if PVSettingsModel.shared.webDavAlwaysOn {
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
                text: NSLocalizedString("Refresh Game Library", comment: ""),
                detailText: .subtitle("Re-import ROMs ⚠️ Slow"),
                icon: nil,
                customization: nil,
                action: { [weak self] _ in
                    self?.refreshGameLibraryAction()
                }
            ),
            NavigationRow(
                text: NSLocalizedString("Empty Image Cache", comment: "Empty Image Cache"),
                detailText: .subtitle("Re-download covers"),
                icon: nil,
                customization: nil,
                action: { [weak self] _ in
                    self?.emptyImageCacheAction()
                }
            ),
            NavigationRow(
                text: NSLocalizedString("Manage Conflicts", comment: ""),
                detailText: .subtitle(numberOfConflicts > 0 ? "Manually resolve conflicted imports: \(numberOfConflicts) detected" : "None detected"),
                icon: nil,
                action: numberOfConflicts > 0 ? { [weak self] _ in self?.manageConflictsAction() } : nil
            ),
            SegueNavigationRow(text: NSLocalizedString("Appearance", comment: "Appearance"),
                               detailText: .subtitle("Visual options for Game Library"),
                               viewController: self, segue: "appearanceSegue")
        ]

        let librarySection2 = Section(title: nil, rows: library2Rows)

         // Beta options
        #if !os(tvOS)

        let betaRows: [TableRow] = [
			PVSettingsSwitchRow(text: NSLocalizedString("Use Metal", comment: "Use Metal"),
								detailText: .subtitle("Use experimental Metal backend instead of OpenGL"),
								key: \PVSettingsModel.debugOptions.useMetal),

            PVSettingsSwitchRow(text: NSLocalizedString("Missing Buttons Always On-Screen", comment: "Missing Buttons Always On-Screen"),
                                detailText: .subtitle("Supports: SNES, SMS, SG, GG, SCD, PSX."),
                                key: \PVSettingsModel.missingButtonsAlwaysOn),

            PVSettingsSwitchRow(text: NSLocalizedString("iCloud Sync", comment: "iCloud Sync"),
                                detailText: .subtitle("Sync core & battery saves, screenshots and BIOS's to iCloud."),
                                key: \PVSettingsModel.debugOptions.iCloudSync),

            PVSettingsSwitchRow(text: NSLocalizedString("Multi-threaded GL", comment: "Multi-threaded GL"),
                                detailText: .subtitle("Use iOS's EAGLContext multiThreaded. May improve or slow down GL performance."),
                                key: \PVSettingsModel.debugOptions.multiThreadedGL),

            PVSettingsSwitchRow(text: NSLocalizedString("4X Multisampling GL", comment: "4X Multisampling GL"),
                                detailText: .subtitle("Use iOS's EAGLContext multisampling. Slower speed (slightly), smoother edges."),
                                key: \PVSettingsModel.debugOptions.multiSampling),

            PVSettingsSwitchRow(text: NSLocalizedString("Unsupported Cores", comment: "Unsupported Cores"),
                                detailText: .subtitle("Cores that are in development"),
                                key: \PVSettingsModel.debugOptions.unsupportedCores),

            PVSettingsSwitchRow(text: NSLocalizedString("Use Swift UI", comment: "Use Swift UI"),
                                detailText: .subtitle("Alternative UI in Swift UI. Not all features supported yet."),
                                key: \PVSettingsModel.debugOptions.useSwiftUI) { cell, row in
//                                    let swiftUIDetailText: DetailText
//                                    if #available(iOS 14, tvOS 14, *) {
//                                        row.
//                                    } else {
//                                        swiftUIDetailText = .subtitle("Only available in iOS/tvOS 14+")
//                                    }
//
//                                    var swiftUI =
//
//                                    if #available(iOS 14, tvOS 14, *) {
//                                        swiftUI.isSelectable = true
//                                    } else {
//                                        swiftUI.isSelectable = false
//                                        swiftUI.switchValue = false
//                                    }
                                },

            PVSettingsSwitchRow(text: NSLocalizedString("Movable Buttons", comment: "Bool option to allow user to move on screen controller buttons"),
								detailText: .subtitle("Allow user to move on screen controller buttons."),
								key: \PVSettingsModel.debugOptions.movableButtons),

            PVSettingsSwitchRow(text: NSLocalizedString("On screen Joypad", comment: ""),
                                detailText: .subtitle("Show a touch Joystick pad on supported systems. Layout is strange on some devices while in beta."),
                                key: \PVSettingsModel.debugOptions.onscreenJoypad),
            PVSettingsSwitchRow(text: NSLocalizedString("On screen Joypad with keyboard", comment: ""),
                                detailText: .subtitle("Show a touch Joystick pad on supported systems when the P1 controller is 'Keyboard'. Useful on iPad OS for systems with an analog joystick (N64, PSX, etc.)"),
                                key: \PVSettingsModel.debugOptions.onscreenJoypadWithKeyboard)
        ]
        #else // tvOS
         let betaRows: [TableRow] = [
            PVSettingsSwitchRow(text: NSLocalizedString("Use Metal", comment: "Use Metal"), detailText: .subtitle("Use experimental Metal backend instead of OpenGL"),
                                key: \PVSettingsModel.debugOptions.useMetal),
            PVSettingsSwitchRow(text: NSLocalizedString("iCloud Sync", comment: "iCloud Sync"),
                                detailText: .subtitle("Sync core & battery saves, screenshots and BIOS's to iCloud."),
                                key: \PVSettingsModel.debugOptions.iCloudSync),

            PVSettingsSwitchRow(text: NSLocalizedString("Multi-threaded GL", comment: "Multi-threaded GL"),
                                detailText: .subtitle("Use tvOS's EAGLContext multiThreaded. May improve or slow down GL performance."),
                                key: \PVSettingsModel.debugOptions.multiThreadedGL),

            PVSettingsSwitchRow(text: NSLocalizedString("4X Multisampling GL", comment: "4X Multisampling GL"),
                                detailText: .subtitle("Use tvOS's EAGLContext multisampling. Slower speed (slightly), smoother edges."),
                                key: \PVSettingsModel.debugOptions.multiSampling),

            PVSettingsSwitchRow(text: NSLocalizedString("Use SwiftUI", comment: "Use SwiftUI"),
                               detailText: .subtitle("Don't use unless you enjoy empty windows."),
                               key: \PVSettingsModel.debugOptions.multiSampling),

            PVSettingsSwitchRow(text: NSLocalizedString("Use Themes", comment: "Use Themes"),
                               detailText: .subtitle("Use iOS themes on tvOS"),
                               key: \PVSettingsModel.debugOptions.tvOSThemes)
                ]
        #endif

        let betaSection = Section(
            title: NSLocalizedString("Beta Features", comment: ""),
            rows: betaRows,
            footer: "Untested, unsupported, work in progress features. Use at your own risk. May result in crashes and data loss."
        )

        // - Social links
        let discordRow = NavigationRow(
            text: NSLocalizedString("Discord", comment: ""),
            detailText: .value2("Join our Discord server for help and community chat."),
            icon: nil,
            customization: nil,
            action: { _ in
                if let url = URL(string: "https://discord.gg/4TK7PU5") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        )
        let twitterRow = NavigationRow(
            text: NSLocalizedString("Twitter", comment: ""),
            detailText: .value2("Follow us on Twitter for release and other announcements."),
            icon: nil,
            customization: nil,
            action: { _ in
                if let url = URL(string: "https://twitter.com/provenanceapp") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        )
        let githubRow = NavigationRow(
            text: NSLocalizedString("GitHub", comment: ""),
            detailText: .value2("Check out GitHub for code, reporting bugs and contributing."),
            icon: nil,
            customization: nil,
            action: { _ in
                if let url = URL(string: "https://github.com/Provenance-Emu/Provenance") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        )
        let patreonRow = NavigationRow(
            text: NSLocalizedString("Patreon", comment: ""),
            detailText: .value2("Support us on Patreaon and receive special features and early access builds."),
            icon: nil,
            customization: nil,
            action: { _ in
                if let url = URL(string: "https://provenance-emu.com/patreon") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        )
        let youTubeRow = NavigationRow(
            text: NSLocalizedString("YouTube!", comment: ""),
            detailText: .value2("Help tutorial videos and new feature previews."),
            icon: nil,
            customization: nil,
            action: { _ in
                if let url = URL(string: "https://www.youtube.com/channel/UCKeN6unYKdayfgLWulXgB1w") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        )
        let blogRow = NavigationRow(
            text: NSLocalizedString("Blog", comment: ""),
            detailText: .value2("Release annoucements and full changelogs and screenshots posted to our blog."),
            icon: nil,
            customization: nil,
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
            detailText: .value2("Frequently asked questions."),
            icon: nil,
            customization: nil,
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
            detailText: .value2("Full usage documentation, tips and tricks on our Wiki."),
            icon: nil,
            customization: nil,
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

        let socialLinksRows = [patreonRow, discordRow, twitterRow, youTubeRow, githubRow]
        let socialLinksSection = Section(title: NSLocalizedString("Socials", comment: ""), rows: socialLinksRows)

        let documentationLinksRow = [blogRow, faqRow, wikiRow]
        let documentationSection = Section(title: NSLocalizedString("Documentation", comment: ""), rows: documentationLinksRow)

        // - Build Information

        #if DEBUG
            let modeLabel = "DEBUG"
        #else
            let modeLabel = "RELEASE"
        #endif

        let branchName = kGITBranch.lowercased()
        let masterBranch: Bool = branchName == "master" || branchName.starts(with: "release")
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        if !masterBranch {
            versionText = "\(versionText ?? "") Beta"
//            versionLabel.textColor = UIColor.init(hex: "#F5F5A0")
        }

        // Git Revision (branch/hash)
        var revisionString = NSLocalizedString("Unknown", comment: "")
        if var bundleRevision = Bundle.main.infoDictionary?["Revision"] as? String, !revisionString.isEmpty {
            if !masterBranch {
                bundleRevision = "\(kGITBranch)/\(bundleRevision)"
            }
            revisionString = bundleRevision
        }

        // Build date string
        let incomingDateFormatter = DateFormatter()
        incomingDateFormatter.dateFormat = "E MMM d HH:mm:ss yyyy"

        let outputDateFormatter = DateFormatter()
        outputDateFormatter.dateFormat = "MM/dd/yyyy hh:mm a"

        var buildDate = Date(timeIntervalSince1970: 0)

        if let processedDate = incomingDateFormatter.date(from: gitdate) {
            buildDate = processedDate
        } else {
            // Try chaninging local - depends on which local was build with for git string
            // more than the current local
            incomingDateFormatter.locale = Locale.current
            if let processedDate = incomingDateFormatter.date(from: gitdate) {
                buildDate = processedDate
            }
        }

        let buildDateString: String = outputDateFormatter.string(from: buildDate)

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
            SegueNavigationRow(text: NSLocalizedString("Cores", comment: "Cores"), detailText: .subtitle("Emulator cores provided by these projects"), viewController: self, segue: "coresSegue", customization: nil),
            SegueNavigationRow(text: NSLocalizedString("Licenses", comment: "Licenses"), detailText: .none, viewController: self, segue: "licensesSegue", customization: nil)
        ]

        let extraInfoSection = Section(title: NSLocalizedString("3rd Party & Legal", comment: ""), rows: extraInfoRows)

        // Debug section
        let debugRows: [TableRow] = [
            NavigationRow(text: NSLocalizedString("Logs", comment: "Logs"),
                                              detailText: .subtitle("Live logging information"),
                                              icon: nil,
                                              customization: nil,
                                              action: { _ in
                                                  self.logsActions()
                                              })
        ]

        let debugSection = Section(title: NSLocalizedString("Debug", comment: ""), rows: debugRows)

        // Set table data
        tableContents = [appSection, coreOptionsSection, savesSection, avSection, metalSection, controllerSection, librarySection, librarySection2, betaSection, socialLinksSection, documentationSection, buildSection, extraInfoSection]
        #if os(iOS)
            tableContents.append(debugSection)
        #endif
    }

    func launchWebServerAction() {
        if reachability.connection == .wifi {
            // connected via wifi, let's continue
            // start web transfer service
            if PVWebServer.shared.startServers() {
                // show alert view
                showServerActiveAlert()
            } else {
                // Display error
                let alert = UIAlertController(title: "Unable to start web server!",
                                              message: "Check your network connection or settings and free up ports: 80, 81.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
                }))
                present(alert, animated: true) { () -> Void in }
            }
        } else {
            let alert = UIAlertController(title: "Unable to start web server!",
                                          message: "Your device needs to be connected to a WiFi network to continue!",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) { () -> Void in }
        }
    }

    func refreshGameLibraryAction() {
        tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
        let alert = UIAlertController(title: "Refresh Game Library?",
                                      message: """
Attempt to reload the artwork and title information for your entire library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork or update the information.

You will need to completely relaunch the App to start the library rebuild process.
""",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes",
                                      style: .default,
                                      handler: { (_: UIAlertAction) -> Void in
            NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
        }))
        alert.addAction(UIAlertAction(title: "No",
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true) { () -> Void in }
    }

    func emptyImageCacheAction() {
        tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
        let alert = UIAlertController(title: NSLocalizedString("Empty Image Cache?", comment: ""),
                                      message: "Empty the image cache to free up disk space. Images will be redownloaded on demand.",
                                      preferredStyle: .alert)
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
        let conflictViewController = PVConflictViewController(conflictsController: conflictsController)
        navigationController?.pushViewController(conflictViewController, animated: true)
    }

    func logsActions() {
        // Log Viewer
        let logViewController = PVLogViewController(nibName: "PVLogViewController", bundle: nil)
        logViewController.hideDoneButton()
        navigationController?.pushViewController(logViewController, animated: true)
        logViewController.hideDoneButton()
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

#if canImport(SafariServices)
    extension PVSettingsViewController: WebServerActivatorController, SFSafariViewControllerDelegate {}
#else
    extension PVSettingsViewController: WebServerActivatorController {}
#endif
