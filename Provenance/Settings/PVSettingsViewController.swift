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
import QuickTableViewController
import Reachability
import RealmSwift
import UIKit

class PVQuickTableViewController: QuickTableViewController {
    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        #if os(iOS)
            (cell as? SliderCell)?.delegate = self
        #endif

        return cell
    }
}

final class PVSettingsViewController: PVQuickTableViewController {
    // Check to see if we are connected to WiFi. Cannot continue otherwise.
    let reachability: Reachability = Reachability()!

    override func viewDidLoad() {
        super.viewDidLoad()
        generateTableViewViewModels()
        tableView.reloadData()

        #if os(iOS)
            navigationItem.leftBarButtonItem?.tintColor = Theme.currentTheme.barButtonItemTint
            navigationItem.rightBarButtonItem?.tintColor = Theme.currentTheme.barButtonItemTint
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

    func generateTableViewViewModels() {
        typealias TableRow = Row & RowStyle

        // -- Section : App
        let autolockRow = PVSettingsSwitchRow(text: "Disable Auto Lock", key: \PVSettingsModel.disableAutoLock)
        let systemsRow = SegueNavigationRow(text: "Systems", viewController: self, segue: "pushSystemSettings")

        #if os(tvOS)
            let appRows: [TableRow] = [systemsRow]
        #else
            let appRows: [TableRow] = [autolockRow, systemsRow]
        #endif

        let appSection = Section(title: "App", rows: appRows)

        // -- Core Options
        let realm = try! Realm()
        let cores: [NavigationRow<SystemSettingsCell>] = realm.objects(PVCore.self).compactMap { pvcore in
            guard let coreClass = NSClassFromString(pvcore.principleClass) as? CoreOptional.Type else {
                DLOG("Class <\(pvcore.principleClass)> does not impliment CoreOptional")
                return nil
            }

            return NavigationRow<SystemSettingsCell>(text: pvcore.projectName, detailText: .none, icon: nil, customization: nil, action: { [weak self] row in
                let coreOptionsVC = CoreOptionsViewController(withCore: coreClass)
                coreOptionsVC.title = row.text
                self?.navigationController?.pushViewController(coreOptionsVC, animated: true)
            })
        }

        let coreOptionsSection = Section(title: "Core Options", rows: cores)

        // -- Section : Saves
        let saveRows: [TableRow] = [
            PVSettingsSwitchRow(text: "Auto Save", key: \PVSettingsModel.autoSave),
            PVSettingsSwitchRow(text: "Timed Auto Saves", key: \PVSettingsModel.timedAutoSaves),
            PVSettingsSwitchRow(text: "Auto Load Saves", key: \PVSettingsModel.autoLoadSaves),
            PVSettingsSwitchRow(text: "Ask to Load Saves", key: \PVSettingsModel.askToAutoLoad),
        ]

        let savesSection = Section(title: "Saves", rows: saveRows)

        // -- Section : Audio/Video
        var avRows = [TableRow]()
        #if os(iOS)
            avRows.append(contentsOf: [PVSettingsSwitchRow(text: "Volume HUD", key: \PVSettingsModel.volumeHUD)])
            avRows.append(PVSettingsSliderRow(text: "Volume", detailText: nil, valueLimits: (min: 0.0, max: 1.0), key: \PVSettingsModel.volume))
        #endif

        avRows.append(contentsOf: [
            PVSettingsSwitchRow(text: "Native Scale", key: \PVSettingsModel.nativeScaleEnabled),
            PVSettingsSwitchRow(text: "CRT Filter", key: \PVSettingsModel.crtFilterEnabled),
            PVSettingsSwitchRow(text: "Image Smoothing", key: \PVSettingsModel.imageSmoothing),
            PVSettingsSwitchRow(text: "FPS Counter", key: \PVSettingsModel.showFPSCount),
        ])

        let avSection = Section(title: "Audio/Video", rows: avRows)

        // -- Section : Controler

        var controllerRows = [TableRow]()

        #if os(iOS)
            controllerRows.append(PVSettingsSliderRow(text: "Opacity", detailText: nil, valueLimits: (min: 0.2, max: 1.0), key: \PVSettingsModel.controllerOpacity))

            controllerRows.append(contentsOf: [
                PVSettingsSwitchRow(text: "Button Colors", key: \PVSettingsModel.buttonTints),
                PVSettingsSwitchRow(text: "All-Right Shoulders", detailText: .subtitle("Moves L1, L2 & Z to right side"), key: \PVSettingsModel.allRightShoulders),
                PVSettingsSwitchRow(text: "Haptic Feedback", key: \PVSettingsModel.buttonVibration),
            ])
        #endif
        controllerRows.append(contentsOf: [
            SegueNavigationRow(text: "Controllers", detailText: .subtitle("Assign players"), viewController: self, segue: "controllersSegue"),
            SegueNavigationRow(text: "iCade Controller", detailText: .subtitle(PVSettingsModel.shared.myiCadeControllerSetting.description), viewController: self, segue: "iCadeSegue", customization: { cell, _ in
                cell.detailTextLabel?.text = PVSettingsModel.shared.myiCadeControllerSetting.description
            }),
        ])

        let controllerSection = Section(title: "Controller", rows: controllerRows, footer: "Check wiki for Controls per systems")

        // Game Library

        var libraryRows: [TableRow] = [
            NavigationRow<SystemSettingsCell>(
                text: "Launch Web Server",
                detailText: .subtitle("Import/Export ROMs, saves, cover art..."),
                icon: nil,
                customization: nil,
                action: { [weak self] _ in
                    self?.launchWebServerAction()
                }
            ),
        ]

        #if os(tvOS)
            let webServerAlwaysOn = PVSettingsSwitchRow(
                text: "Web Server Always-On",
                detailText: .subtitle(""),
                key: \PVSettingsModel.webDavAlwaysOn,
                customization: { cell, _ in
                    if PVSettingsModel.shared.webDavAlwaysOn {
                        let subTitleText = "\nWebDav: \(PVWebServer.shared.webDavURLString)"

                        let subTitleAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 26), NSAttributedString.Key.foregroundColor: UIColor.gray]
                        let subTitleAttrString = NSMutableAttributedString(string: subTitleText, attributes: subTitleAttributes)
                        cell.detailTextLabel?.attributedText = subTitleAttrString
                    } else {
                        cell.detailTextLabel?.text = nil
                        cell.detailTextLabel?.attributedText = nil
                    }
                }
            )
            libraryRows.append(webServerAlwaysOn)
        #endif

        let librarySection = Section(title: "Game Library", rows: libraryRows, footer: "Check the wiki about Importing ROMs.")

        // Game Library 2
        let library2Rows: [TableRow] = [
            NavigationRow<SystemSettingsCell>(
                text: "Refresh Game Library",
                detailText: .subtitle("Re-import ROMs ⚠️ Slow"),
                icon: nil,
                customization: nil,
                action: { [weak self] _ in
                    self?.refreshGameLibraryAction()
                }
            ),
            NavigationRow<SystemSettingsCell>(
                text: "Empty Image Cache",
                detailText: .subtitle("Re-download covers"),
                icon: nil,
                customization: nil,
                action: { [weak self] _ in
                    self?.emptyImageCacheAction()
                }
            ),
            NavigationRow<SystemSettingsCell>(
                text: "Manage Conflicts",
                detailText: .subtitle("Manually resolve conflicted imports"),
                icon: nil,
                customization: { cell, _ in
                    let baseTitle = "Manually resolve conflicted imports"
                    let detailText: String
                    if let count = GameImporter.shared.conflictedFiles?.count, count > 0 {
                        detailText = baseTitle + ": \(count) detected"
                    } else {
                        detailText = baseTitle + ": None detected"
                    }

                    cell.detailTextLabel?.text = detailText
                },
                action: { [weak self] _ in self?.manageConflictsAction() }
            ),
            SegueNavigationRow(text: "Appearance", detailText: .subtitle("Visual options for Game Library"), viewController: self, segue: "appearanceSegue"),
        ]

        let librarySection2 = Section(title: nil, rows: library2Rows)

        // Beta options
        let betaRows: [TableRow] = [
            PVSettingsSwitchRow(text: "Missing Buttons Always On-Screen",
                                detailText: .subtitle("Supports: SNES, SMS, SG, GG, SCD, PSX"),
                                key: \PVSettingsModel.missingButtonsAlwaysOn),

            PVSettingsSwitchRow(text: "iCloud Sync",
                                detailText: .subtitle("Sync core & battery saves, screenshots and BIOS's to iCloud"),
                                key: \PVSettingsModel.debugOptions.iCloudSync),

            PVSettingsSwitchRow(text: "Multi-threaded GL",
                                detailText: .subtitle("Use iOS's EAGLContext multiThreaded. May improve or slow down GL performance."),
                                key: \PVSettingsModel.debugOptions.multiThreadedGL),

            PVSettingsSwitchRow(text: "4X Multisampling GL",
                                detailText: .subtitle("Use iOS's EAGLContext multisampling. Slower speed (slightly), smoother edges."),
                                key: \PVSettingsModel.debugOptions.multiSampling),

//            PVSettingsSwitchRow(text: "Unsupported Cores",
//                                detailText: .subtitle("Cores that are in development"),
//                                key: \PVSettingsModel.debugOptions.unsupportedCores)
        ]

        let betaSection = Section(
            title: "Beta Features",
            rows: betaRows,
            footer: "Untested, unsupported, work in progress features. Use at your own risk. May result in crashes and data loss."
        )

        // Build Information

        #if DEBUG
            let modeLabel = "DEBUG"
        #else
            let modeLabel = "RELEASE"
        #endif

        let masterBranch: Bool = kGITBranch.lowercased() == "master"
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        if !masterBranch {
            versionText = "\(versionText ?? "") Beta"
//            versionLabel.textColor = UIColor.init(hex: "#F5F5A0")
        }

        // Git Revision (branch/hash)
        var revisionString = "Unknown"
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
            NavigationRow<SystemSettingsCell>(
                text: "Version",
                detailText: .value2(versionText ?? "Unknown"),
                icon: nil,
                customization: { cell, _ in
                    if !masterBranch {
                        cell.detailTextLabel?.textColor = UIColor(hex: "#F5F5A0")
                    }
                },
                action: nil
            ),
            NavigationRow<SystemSettingsCell>(text: "Build", detailText: .value2(bundleVersion)),
            NavigationRow<SystemSettingsCell>(text: "Mode", detailText: .value2(modeLabel)),
            NavigationRow<SystemSettingsCell>(text: "Git Revision", detailText: .value2(revisionString)),
            NavigationRow<SystemSettingsCell>(text: "Build Date", detailText: .value2(buildDateString)),
            NavigationRow<SystemSettingsCell>(text: "Builder", detailText: .value2(builtByUser)),
            NavigationRow<SystemSettingsCell>(text: "Bundle ID", detailText: .value2(Bundle.main.bundleIdentifier ?? "Unknown")),
        ]

        let buildSection = Section(title: "Build Information", rows: buildInformationRows)

        // Extra Info Section
        let extraInfoRows: [TableRow] = [
            SegueNavigationRow(text: "Cores", detailText: .subtitle("Emulator cores provided by these projects"), viewController: self, segue: "coresSegue", customization: nil),
            SegueNavigationRow(text: "Licenses", detailText: .none, viewController: self, segue: "licensesSegue", customization: nil),
        ]

        let extraInfoSection = Section(title: "3rd Party & Legal", rows: extraInfoRows)

        // Debug section
        let debugRows: [TableRow] = [
            NavigationRow<SystemSettingsCell>(text: "Logs", detailText: .subtitle("Live logging information"), icon: nil, customization: nil, action: { _ in
                self.logsActions()
            }),
        ]

        let debugSection = Section(title: "Debug", rows: debugRows)

        // Set table data
        #if os(tvOS)
            tableContents = [appSection, coreOptionsSection, savesSection, avSection, controllerSection, librarySection, librarySection2, betaSection, buildSection, extraInfoSection]
        #else
            tableContents = [appSection, coreOptionsSection, savesSection, avSection, controllerSection, librarySection, librarySection2, betaSection, buildSection, extraInfoSection, debugSection]
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
                let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or settings and free up ports: 80, 81", preferredStyle: .alert)
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
        let alert = UIAlertController(title: "Refresh Game Library?", message: "Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_: UIAlertAction) -> Void in
            NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        present(alert, animated: true) { () -> Void in }
    }

    func emptyImageCacheAction() {
        tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
        let alert = UIAlertController(title: "Empty Image Cache?", message: "Empty the image cache to free up disk space. Images will be redownload on demand.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_: UIAlertAction) -> Void in
            try? PVMediaCache.empty()
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        present(alert, animated: true) { () -> Void in }
    }

    func manageConflictsAction() {
        let gameImporter = GameImporter.shared
        let conflictViewController = PVConflictViewController(gameImporter: gameImporter)
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
            let webVC = WebkitViewController(url: URL(string: "https://github.com/Provenance-Emu/Provenance/wiki")!)
            navigationController?.pushViewController(webVC, animated: true)
        #endif
    }
}

#if canImport(SafariServices)
    extension PVSettingsViewController: WebServerActivatorController, SFSafariViewControllerDelegate {}
#else
    extension PVSettingsViewController: WebServerActivatorController {}
#endif
