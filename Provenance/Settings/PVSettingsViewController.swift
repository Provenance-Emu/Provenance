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
import UIKit
import PVLibrary
import PVSupport
import QuickTableViewController

// Subclass to help with themeing
@objc public final class SettingsTableView: UITableView {
    #if os(iOS)
    public override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        self.backgroundColor = Theme.currentTheme.settingsHeaderBackground
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = Theme.currentTheme.settingsHeaderBackground
    }
    #endif
}

final class PVSwitchCell : SwitchCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.style()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        style()
    }

    func style() {
        let bg = UIView(frame: bounds)
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        #if os(iOS)
        bg.backgroundColor = Theme.currentTheme.settingsCellBackground
        self.textLabel?.textColor = Theme.currentTheme.settingsCellText
        self.detailTextLabel?.textColor = Theme.currentTheme.defaultTintColor
        self.switchControl.onTintColor = Theme.currentTheme.switchON
        self.switchControl.thumbTintColor = Theme.currentTheme.switchThumb

        #else
        bg.backgroundColor = UIColor.clear
        if #available(tvOS 10.0, *) {
            self.textLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.white : UIColor.black
            self.detailTextLabel?.textColor = traitCollection.userInterfaceStyle != .light ? UIColor.lightGray : UIColor.darkGray
        }
        #endif
        self.backgroundView = bg
    }
}

final class PVSettingsSwitchRow : SwitchRow<PVSwitchCell> {

    let keyPath : ReferenceWritableKeyPath<PVSettingsModel, Bool>

    required init(title: String, subtitle: Subtitle? = nil, key: ReferenceWritableKeyPath<PVSettingsModel, Bool>, customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil) {
        self.keyPath = key
        let value = PVSettingsModel.shared[keyPath: key]

        super.init(title: title, switchValue: value, customization: customization, action: { row in
            if let row = row as? SwitchRowCompatible {
                PVSettingsModel.shared[keyPath: key] = row.switchValue
            }
        })
    }
}

final class SegueNavigationRow :  NavigationRow<SystemSettingsCell> {
    weak var viewController : UIViewController?

    required init(title: String, subtitle: Subtitle = .none, viewController: UIViewController, segue: String, customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil) {
        self.viewController = viewController

        super.init(title: title, subtitle: subtitle, icon: nil, customization: customization) {[weak viewController] (row) in
            guard let viewController = viewController else {return}

            viewController.performSegue(withIdentifier: segue, sender: nil)
        }
    }
}

final class PVSettingsViewController : QuickTableViewController {

    // Check to see if we are connected to WiFi. Cannot continue otherwise.
    let reachability : Reachability = Reachability.forLocalWiFi()

    override func viewDidLoad() {
        super.viewDidLoad()
        generateTableViewViewModels()
        tableView.reloadData()
    }

    func generateTableViewViewModels() {
        typealias TableRow = Row & RowStyle

        // -- Section : App
        let autolockRow = PVSettingsSwitchRow(title: "Disable Auto Lock", key: \PVSettingsModel.disableAutoLock)
        let systemsRow = SegueNavigationRow(title: "Systems", viewController: self, segue: "pushSystemSettings")

        #if os(tvOS)
        let appRows : [TableRow] = [systemsRow]
        #else
        let appRows : [TableRow] = [autolockRow, systemsRow]
        #endif

        let appSection = Section(title: "App", rows: appRows)

        // -- Section : Saves
        let saveRows : [TableRow] = [
            PVSettingsSwitchRow(title: "Auto Save", key: \PVSettingsModel.autoSave),
            PVSettingsSwitchRow(title: "Timed Auto Saves", key: \PVSettingsModel.timedAutoSaves),
            PVSettingsSwitchRow(title: "Auto Load Saves", key: \PVSettingsModel.autoLoadSaves),
            PVSettingsSwitchRow(title: "Ask to Load Saves", key: \PVSettingsModel.askToAutoLoad)
        ]

        let savesSection = Section(title: "Saves", rows: saveRows)

        // -- Section : Audio/Video
        var avRows = [TableRow]()
        #if os(iOS)
        avRows.append(contentsOf: [PVSettingsSwitchRow(title: "Volume HUD", key: \PVSettingsModel.volumeHUD),
                                   PVSettingsSwitchRow(title: "Native Scale", key: \PVSettingsModel.nativeScaleEnabled)
                                   ])
        #endif
        avRows.append(contentsOf: [
            // TODO: Volume slider
            PVSettingsSwitchRow(title: "CRT Filter", key: \PVSettingsModel.crtFilterEnabled),
            PVSettingsSwitchRow(title: "Image Smoothing", key: \PVSettingsModel.imageSmoothing),
            PVSettingsSwitchRow(title: "FPS Counter", key: \PVSettingsModel.showFPSCount)
        ])

        let avSection = Section(title: "Audio/Video", rows: avRows)

        // -- Section : Controler

        var controllerRows = [TableRow]()

        #if os(iOS)
        controllerRows.append(contentsOf: [
            // TODO: Opacity slider
            PVSettingsSwitchRow(title: "Button Colors", key: \PVSettingsModel.buttonTints),
            PVSettingsSwitchRow(title: "Start/Select Always", subtitle: Subtitle.belowTitle("Supports: SNES, SMS, SG, GG, SCD, PSX"), key: \PVSettingsModel.startSelectAlwaysOn),
            PVSettingsSwitchRow(title: "All-Right Shoulder", subtitle: .belowTitle("Moves L1, L2 & Z to right side"), key: \PVSettingsModel.allRightShoulders),
            PVSettingsSwitchRow(title: "Haptic Feedback", key: \PVSettingsModel.buttonVibration)
            ])
        #endif
        controllerRows.append(contentsOf: [
            SegueNavigationRow(title: "Controllers", subtitle: .belowTitle("Assign players"), viewController: self, segue: "controllersSegue"),
            SegueNavigationRow(title: "iCade Controller", subtitle: .belowTitle(PVSettingsModel.shared.myiCadeControllerSetting.description), viewController: self, segue: "iCadeSegue", customization: { (cell, row) in
                cell.detailTextLabel?.text = PVSettingsModel.shared.myiCadeControllerSetting.description
            })
            ])

        let controllerSection = Section(title: "Controller", rows: controllerRows, footer: "Check wiki for Controls per systems")

        // Game Library

        var libraryRows : [TableRow] = [
            NavigationRow<SystemSettingsCell>(title: "Launch Web Server", subtitle: .belowTitle("Import/Export ROMs, saves, cover art..."), icon: nil, customization: nil, action: {[weak self] (row) in
                self?.launchWebServerAction()
            })
        ]

        #if os(tvOS)
        let webServerAlwaysOn = PVSettingsSwitchRow(title: "Web Server Always-On",
                                                    subtitle: .belowTitle(""),
                                                    key: \PVSettingsModel.webDavAlwaysOn,
                                                    customization: { (cell, row) in
                                                        if PVSettingsModel.shared.webDavAlwaysOn {
                                                            let subTitleText = "\nWebDav: \(PVWebServer.shared.webDavURLString)"

                                                            let subTitleAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 26), NSAttributedString.Key.foregroundColor: UIColor.gray]
                                                            let subTitleAttrString = NSMutableAttributedString(string: subTitleText, attributes: subTitleAttributes)
                                                            cell.detailTextLabel?.attributedText = subTitleAttrString
                                                        } else {
                                                            cell.detailTextLabel?.text = nil
                                                            cell.detailTextLabel?.attributedText = nil
                                                        }
        })
        libraryRows.append(webServerAlwaysOn)
        #endif

        let librarySection = Section(title: "Game Library", rows: libraryRows, footer: "Check the wiki about Importing ROMs.")

        // Game Library 2
        let library2Rows : [TableRow] = [
            NavigationRow<SystemSettingsCell>(title: "Refresh Game Library", subtitle: .belowTitle("Re-import ROMs ⚠️ Slow"), icon: nil, customization: nil, action: {[weak self] (row) in
                self?.refreshGameLibraryAction()
            }),
            NavigationRow<SystemSettingsCell>(title: "Empty Image Cache", subtitle: .belowTitle("Re-download covers"), icon: nil, customization: nil, action: {[weak self] (row) in
                self?.emptyImageCacheAction()
            }),
            NavigationRow<SystemSettingsCell>(title: "Manage Conflicts",
                          subtitle: .belowTitle("Manually resolve conflicted imports"),
                          icon: nil,
                          customization: { (cell, row) in
                            let baseTitle = "Manually resolve conflicted imports"
                            let subTitle : String
                            if let count = PVGameImporter.shared.conflictedFiles?.count, count > 0 {
                                subTitle = baseTitle + ": \(count) detected"
                            } else {
                                subTitle = baseTitle + ": None detected"
                            }

                            cell.detailTextLabel?.text = subTitle
                },
                          action: {[weak self] (row) in self?.manageConflictsAction() }),
            SegueNavigationRow(title: "Appearance", subtitle: .belowTitle("Visual options for Game Library"), viewController: self, segue: "appearanceSegue")
        ]

        let librarySection2 = Section(title: nil, rows: library2Rows)

        // Build Information

        #if DEBUG
        let modeLabel = "DEBUG"
        #else
        let modeLabel = "RELEASE"
        #endif

        let masterBranch : Bool = kGITBranch.lowercased() == "master"
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

        let buildDateString : String = outputDateFormatter.string(from: buildDate)

        let buildInformationRows : [TableRow] = [
            NavigationRow<SystemSettingsCell>(title: "Version",
                          subtitle: .rightAligned(versionText ?? "Unknown"),
                          icon: nil,
                          customization: { (cell, row) in
                            if !masterBranch {
                                cell.detailTextLabel?.textColor = UIColor(hex: "#F5F5A0")
                            }
            },
                          action: nil),
            NavigationRow<SystemSettingsCell>(title: "Build", subtitle: .rightAligned(bundleVersion)),
            NavigationRow<SystemSettingsCell>(title: "Mode", subtitle: .rightAligned(modeLabel)),
            NavigationRow<SystemSettingsCell>(title: "Git Revision", subtitle: .rightAligned(revisionString)),
            NavigationRow<SystemSettingsCell>(title: "Build Date", subtitle: .rightAligned(buildDateString)),
            NavigationRow<SystemSettingsCell>(title: "Builder", subtitle: .rightAligned(builtByUser)),
            NavigationRow<SystemSettingsCell>(title: "Bundle ID", subtitle: .rightAligned(Bundle.main.bundleIdentifier ?? "Unknown"))
        ]

        let buildSection = Section(title: "Build Information", rows: buildInformationRows)

        // Extra Info Section
        let extraInfoRows : [TableRow] = [
            SegueNavigationRow(title: "Cores", subtitle: .belowTitle("Emulator cores provided by these projects"), viewController: self, segue: "coresSegue", customization: nil),
            SegueNavigationRow(title: "Licenses", subtitle: .none, viewController: self, segue: "licensesSegue", customization: nil)
        ]

        let extraInfoSection = Section(title: "3rd Party & Legal", rows: extraInfoRows)

        // Debug section
        let debugRows : [TableRow] = [
            NavigationRow<SystemSettingsCell>(title: "Logs", subtitle: .belowTitle("Live logging information"), icon: nil, customization: nil, action: { (row) in
                self.logsActions()
            })
        ]

        let debugSection = Section(title: "Debug", rows: debugRows)

        // Set table data
        #if os(tvOS)
        self.tableContents = [appSection, savesSection, avSection, controllerSection, librarySection, librarySection2, buildSection, extraInfoSection]
        #else
        self.tableContents = [appSection, savesSection, avSection, controllerSection, librarySection, librarySection2, buildSection, extraInfoSection, debugSection]
        #endif
    }

    func launchWebServerAction() {
        let status: NetworkStatus = reachability.currentReachabilityStatus()

        if status != .reachableViaWiFi {
            let alert = UIAlertController(title: "Unable to start web server!", message: "Your device needs to be connected to a WiFi network to continue!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) {() -> Void in }
        } else {
            // connected via wifi, let's continue
            // start web transfer service
            if PVWebServer.shared.startServers() {
                //show alert view
                showServerActiveAlert()
            } else {
                // Display error
                let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or settings and free up ports: 80, 81", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                }))
                present(alert, animated: true) {() -> Void in }
            }
        }
    }

    func refreshGameLibraryAction() {
        tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
        let alert = UIAlertController(title: "Refresh Game Library?", message: "Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        present(alert, animated: true) {() -> Void in }
    }

    func emptyImageCacheAction() {
        tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
        let alert = UIAlertController(title: "Empty Image Cache?", message: "Empty the image cache to free up disk space. Images will be redownload on demand.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            try? PVMediaCache.empty()
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        present(alert, animated: true) {() -> Void in }
    }

    func manageConflictsAction() {
        let gameImporter = PVGameImporter.shared
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

    @IBAction func done(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) {() -> Void in }
    }

    @IBAction func help(_ sender: Any) {
        #if canImport(SafariServices)
        let webVC = WebkitViewController(url: URL(string: "https://github.com/Provenance-Emu/Provenance/wiki")!)
        navigationController?.pushViewController(webVC, animated: true)
        #endif
    }
}

#if canImport(SafariServices)
extension PVSettingsViewController : WebServerActivatorController, SFSafariViewControllerDelegate { }
#else
extension PVSettingsViewController : WebServerActivatorController { }
#endif

//final class PVSettingsViewController: UITableViewController, SFSafariViewControllerDelegate, WebServerActivatorController {
//    @IBOutlet weak var autoSaveSwitch: UISwitch!
//    @IBOutlet weak var autoLoadSwitch: UISwitch!
//    @IBOutlet weak var timedAutoSavesSwitch: UISwitch!
//    @IBOutlet weak var timedAutoSavesCell: UITableViewCell!
//    @IBOutlet weak var askToLoadSwitch: UISwitch!
//    @IBOutlet weak var askToLoadSavesCell: UITableViewCell!
//    @IBOutlet weak var autoLockSwitch: UISwitch!
//    @IBOutlet weak var vibrateSwitch: UISwitch!
//    @IBOutlet weak var imageSmoothing: UISwitch!
//    @IBOutlet weak var nativeScaleSwitch: UISwitch!
//    @IBOutlet weak var crtFilterSwitch: UISwitch!
//    @IBOutlet weak var opacitySlider: UISlider!
//    @IBOutlet weak var opacityValueLabel: UILabel!
//    @IBOutlet weak var versionLabel: UILabel!
//    @IBOutlet weak var revisionLabel: UILabel!
//    @IBOutlet weak var buildNumberLabel: UILabel!
//    @IBOutlet weak var modeLabel: UILabel!
//    @IBOutlet weak var iCadeControllerSetting: UILabel!
//    @IBOutlet weak var volumeSlider: UISlider!
//    @IBOutlet weak var volumeValueLabel: UILabel!
//    @IBOutlet weak var fpsCountSwitch: UISwitch!
//    @IBOutlet weak var tintSwitch: UISwitch!
//    @IBOutlet weak var startSelectSwitch: UISwitch!
//    @IBOutlet weak var volumeHUDSwitch: UISwitch!
//    @IBOutlet weak var allRightShouldersSwitch: UISwitch!
//    @IBOutlet weak var themeValueLabel: UILabel!
//    @IBOutlet weak var buildDateLabel: UILabel!
//    @IBOutlet weak var builderLabel: UILabel!
//    @IBOutlet weak var bundleIDLabel: UILabel!
//
//    var gameImporter: PVGameImporter?
//
//    @IBAction func wikiLinkButton(_ sender: Any) {
//        let webVC = WebkitViewController(url: URL(string: "https://github.com/Provenance-Emu/Provenance/wiki/Formatting-ROMs")!)
//        navigationController?.pushViewController(webVC, animated: true)
//    }
//
//    @IBAction func done(_ sender: Any) {
//        presentingViewController?.dismiss(animated: true) {() -> Void in }
//    }
//
//    // Check to see if we are connected to WiFi. Cannot continue otherwise.
//    lazy var reachability : Reachability = Reachability.forLocalWiFi()
//
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//        reachability.stopNotifier()
//    }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        title = "Settings"
//        let settings = PVSettingsModel.shared
//        autoSaveSwitch.isOn = settings.autoSave
//        timedAutoSavesSwitch.isOn = settings.timedAutoSaves
//        autoLoadSwitch.isOn = settings.autoLoadSaves
//        askToLoadSwitch.isOn = settings.askToAutoLoad
//        opacitySlider.value = Float(settings.controllerOpacity)
//        autoLockSwitch.isOn = settings.disableAutoLock
//        vibrateSwitch.isOn = settings.buttonVibration
//        imageSmoothing.isOn = settings.imageSmoothing
//        crtFilterSwitch.isOn = settings.crtFilterEnabled
//        nativeScaleSwitch.isOn = settings.nativeScaleEnabled
//        fpsCountSwitch.isOn = settings.showFPSCount
//        tintSwitch.isOn = settings.buttonTints
//        startSelectSwitch.isOn = settings.startSelectAlwaysOn
//        allRightShouldersSwitch.isOn = settings.allRightShoulders
//        volumeHUDSwitch.isOn = settings.volumeHUD
//        volumeSlider.value = settings.volume
//        volumeValueLabel.text = String(format: "%.0f%%", volumeSlider.value * 100)
//        opacityValueLabel.text = String(format: "%.0f%%", opacitySlider.value * 100)
//
//        let masterBranch = kGITBranch.lowercased() == "master"
//
//        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
//        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
//        if !masterBranch {
//            versionText = "\(versionText ?? "") Beta"
//            versionLabel.textColor = UIColor.init(hex: "#F5F5A0")
//        }
//
//        versionLabel.text = versionText
//#if DEBUG
//        modeLabel.text = "DEBUG"
//#else
//        modeLabel.text = "RELEASE"
//#endif
//        let color: UIColor? = UIColor(white: 0.0, alpha: 0.1)
//        if var revisionString = Bundle.main.infoDictionary?["Revision"] as? String, !revisionString.isEmpty {
//            if !masterBranch {
//                revisionString = "\(kGITBranch)/\(revisionString)"
//            }
//            revisionLabel.text = revisionString
//        } else {
//            revisionLabel.textColor = color ?? UIColor.clear
//            revisionLabel.text = "(none)"
//        }
//
//        buildNumberLabel.text = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "nil"
//
//        let incomingDateFormatter = DateFormatter()
//        incomingDateFormatter.dateFormat = "E MMM d HH:mm:ss yyyy"
//
//        let outputDateFormatter = DateFormatter()
//        outputDateFormatter.dateFormat = "MM/dd/yyyy hh:mm a"
//
//        var buildDate = Date(timeIntervalSince1970: 0)
//
//        if let processedDate = incomingDateFormatter.date(from: gitdate) {
//            buildDate = processedDate
//        } else {
//            // Try chaninging local - depends on which local was build with for git string
//            // more than the current local
//            incomingDateFormatter.locale = Locale.current
//            if let processedDate = incomingDateFormatter.date(from: gitdate) {
//                buildDate = processedDate
//            }
//        }
//
//        buildDateLabel.text = outputDateFormatter.string(from: buildDate)
//        bundleIDLabel.text = Bundle.main.bundleIdentifier
//        builderLabel.text = builtByUser
//    }
//
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//    }
//
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//        reachability.startNotifier()
//
//        let settings = PVSettingsModel.shared
//        iCadeControllerSetting.text = settings.myiCadeControllerSetting.description
//
////        if #available(iOS 9.0, *) {
////            themeValueLabel.text = settings.theme.rawValue
////        }
//    }
//
//    override func viewDidAppear(_ animated: Bool) {
//        // placed for animation use later…
//    }
//
//    override func viewDidLayoutSubviews() {
//        if PVSettingsModel.sharedInstance().autoLoadSaves == true {
//            disableAskToLoadSavesCell()
//            disableAutoLoadSaves()
//        } else {
//            enableAskToLoadSavesCell()
//        }
//        if PVSettingsModel.sharedInstance().autoSave == false {
//            disableTimedAutoSaveCell()
//            disableTimedAutoSaves()
//        } else {
//            enableTimedAutoSavesCell()
//        }
//    }
//
//    @IBAction func help(_ sender: Any) {
//        let webVC = WebkitViewController(url: URL(string: "https://github.com/Provenance-Emu/Provenance/wiki")!)
//        navigationController?.pushViewController(webVC, animated: true)
//    }
//
//    @IBAction func toggleFPSCount(_ sender: Any) {
//        PVSettingsModel.shared.showFPSCount = fpsCountSwitch.isOn
//    }
//
//    @IBAction func toggleAutoSave(_ sender: Any) {
//        PVSettingsModel.shared.autoSave = autoSaveSwitch.isOn
//        if autoSaveSwitch.isOn {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.enableTimedAutoSavesCell()
//            }, completion: nil)
//        } else {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.disableTimedAutoSaveCell()
//            }, completion: nil)
//            disableTimedAutoSaves()
//        }
//    }
//
//    @IBAction func toggleAutoLoadSaves(_ sender: Any) {
//        PVSettingsModel.shared.autoLoadSaves = autoLoadSwitch.isOn
//        if autoLoadSwitch.isOn {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.disableAskToLoadSavesCell()
//            }, completion: nil)
//            disableAutoLoadSaves()
//        } else {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.enableAskToLoadSavesCell()
//            }, completion: nil)
//        }
//    }
//
//    @IBAction func toggleTimedAutoSaves(_ sender: Any) {
//        PVSettingsModel.shared.timedAutoSaves = timedAutoSavesSwitch.isOn
//    }
//
//    @IBAction func toggleAskToLoadSaves(_ sender: Any) {
//        PVSettingsModel.shared.askToAutoLoad = askToLoadSwitch.isOn
//    }
//
//    @IBAction func controllerOpacityChanged(_ sender: Any) {
//        opacitySlider.value = floor(opacitySlider.value / Float(0.05)) * Float(0.05)
//        opacityValueLabel.text = String(format: "%.0f%%", opacitySlider.value * Float(100.0))
//        PVSettingsModel.shared.controllerOpacity = CGFloat(opacitySlider.value)
//    }
//
//    @IBAction func toggleAutoLock(_ sender: Any) {
//        PVSettingsModel.shared.disableAutoLock = autoLockSwitch.isOn
//    }
//
//    @IBAction func toggleVibration(_ sender: Any) {
//        PVSettingsModel.shared.buttonVibration = vibrateSwitch.isOn
//    }
//
//    @IBAction func toggleSmoothing(_ sender: Any) {
//        PVSettingsModel.shared.imageSmoothing = imageSmoothing.isOn
//    }
//
//    @IBAction func toggleCRTFilter(_ sender: Any) {
//        PVSettingsModel.shared.crtFilterEnabled = crtFilterSwitch.isOn
//    }
//
//    @IBAction func toggleNativeScale(_ sender: Any) {
//        PVSettingsModel.shared.nativeScaleEnabled = nativeScaleSwitch.isOn
//    }
//
//    @IBAction func volumeChanged(_ sender: Any) {
//        PVSettingsModel.shared.volume = volumeSlider.value
//        volumeValueLabel.text = String(format: "%.0f%%", volumeSlider.value * 100)
//    }
//
//    @IBAction func toggleButtonTints(_ sender: Any) {
//        PVSettingsModel.sharedInstance().buttonTints = tintSwitch.isOn
//    }
//
//    @IBAction func toggleStartSelectAlwaysOn(_ sender: Any) {
//        PVSettingsModel.sharedInstance().startSelectAlwaysOn = startSelectSwitch.isOn
//    }
//
//    @IBAction func toggleVolumeHUD(_ sender: Any) {
//        PVSettingsModel.sharedInstance().volumeHUD = volumeHUDSwitch.isOn
//    }
//
//    @IBAction func toggleAllRightShoulders(_ sender: Any) {
//        PVSettingsModel.sharedInstance().allRightShoulders = allRightShouldersSwitch.isOn
//    }
//
//    func disableTimedAutoSaveCell() {
//        timedAutoSavesCell.alpha = 0.5
//        timedAutoSavesSwitch.isEnabled = false
//    }
//
//    func disableTimedAutoSaves() {
//        timedAutoSavesSwitch.setOn(false, animated: true)
//        PVSettingsModel.sharedInstance().timedAutoSaves = false
//    }
//
//    func enableTimedAutoSavesCell() {
//        timedAutoSavesCell.alpha = 1.0
//        timedAutoSavesSwitch.isEnabled = true
//    }
//
//    func disableAskToLoadSavesCell() {
//        askToLoadSavesCell.alpha = 0.5
//        askToLoadSwitch.isEnabled = false
//    }
//
//    func disableAutoLoadSaves() {
//        askToLoadSwitch.setOn(false, animated: true)
//        PVSettingsModel.sharedInstance().askToAutoLoad = false
//    }
//
//    func enableAskToLoadSavesCell() {
//        askToLoadSavesCell.alpha = 1.0
//        askToLoadSwitch.isEnabled = true
//    }
//
//    // Show web server (stays on)
//    @available(iOS 9.0, *)
//    func showServer() {
//        let ipURL: String = PVWebServer.shared.urlString
//        let safariVC = SFSafariViewController(url: URL(string: ipURL)!, entersReaderIfAvailable: false)
//        safariVC.delegate = self
//        present(safariVC, animated: true) {() -> Void in }
//    }
//
//    @available(iOS 9.0, *)
//    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
//        // Load finished
//    }
//
//    // Dismiss and shut down web server
//    @available(iOS 9.0, *)
//    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
//        // Done button pressed
//        navigationController?.popViewController(animated: true)
//        PVWebServer.shared.stopServers()
//    }
//
//    private struct Selections {
//        #if os(iOS)
//        enum Sections : Int {
//            case app = 0
//            case saves
//            case audioVideo
//            case controller
//            case gameLibrary
//            case gameLibrary2
//            case buildInformation
//            case externalInformation
//            case debug
//        }
//        #elseif os(tvOS)
//        enum Sections : Int {
//            case saves = 0
//            case audioVideo
//            case controller
//            case gameLibrary
//            case gameLibrary2
//            case buildInformation
//            case externalInformation
//        }
//        #endif
//        static let launchWebServer    = IndexPath(row: 0, section: Sections.gameLibrary.rawValue)
//
//        static let refreshGameLibrary = IndexPath(row: 0, section: Sections.gameLibrary2.rawValue)
//        static let emptyImageCache    = IndexPath(row: 1, section: Sections.gameLibrary2.rawValue)
//        static let manageConflicts    = IndexPath(row: 2, section: Sections.gameLibrary2.rawValue)
//        static let appearance         = IndexPath(row: 3, section: Sections.gameLibrary2.rawValue)
//
//        static let cores              = IndexPath(row: 0, section: Sections.gameLibrary2.rawValue)
//        static let licenses           = IndexPath(row: 1, section: Sections.gameLibrary2.rawValue)
//
//        static let logs               = IndexPath(row: 0, section: Sections.debug.rawValue)
//    }
//
//    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        switch indexPath {
//        case Selections.launchWebServer:
//            // import/export roms and game saves button
//            tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
//
//            let status: NetworkStatus = reachability.currentReachabilityStatus()
//
//            if status != .reachableViaWiFi {
//                let alert = UIAlertController(title: "Unable to start web server!", message: "Your device needs to be connected to a WiFi network to continue!", preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
//                }))
//                present(alert, animated: true) {() -> Void in }
//            } else {
//                // connected via wifi, let's continue
//                // start web transfer service
//                if PVWebServer.shared.startServers() {
//                    //show alert view
//                    showServerActiveAlert()
//                } else {
//                    // Display error
//                    let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or settings and free up ports: 80, 81", preferredStyle: .alert)
//                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
//                    }))
//                    present(alert, animated: true) {() -> Void in }
//                }
//            }
//        case Selections.refreshGameLibrary:
//            tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
//            let alert = UIAlertController(title: "Refresh Game Library?", message: "Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes.", preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
//                NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
//            }))
//            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
//            present(alert, animated: true) {() -> Void in }
//        case Selections.emptyImageCache:
//            tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
//            let alert = UIAlertController(title: "Empty Image Cache?", message: "Empty the image cache to free up disk space. Images will be redownload on demand.", preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
//                try? PVMediaCache.empty()
//            }))
//            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
//            present(alert, animated: true) {() -> Void in }
//        case Selections.manageConflicts:
//            if let gameImporter = gameImporter {
//                let conflictViewController = PVConflictViewController(gameImporter: gameImporter)
//                navigationController?.pushViewController(conflictViewController, animated: true)
//            } else {
//                ELOG("No game importer instance")
//            }
////        case Selections.appearance:
////            if #available(iOS 9.0, *) {
////                let themeSelectorViewController = ThemeSelectorViewController()
////                navigationController?.pushViewController(themeSelectorViewController, animated: true)
////            } else {
////                let alert = UIAlertController(title: "Not Available", message: "Themes are only available in iOS 9 and above.", preferredStyle: .alert)
////                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
////                present(alert, animated: true, completion: nil)
////            }
//        case Selections.cores:
//            break
//        case Selections.licenses:
//            break
//        case Selections.logs:
//            // Log Viewer
//            let logViewController = PVLogViewController(nibName: "PVLogViewController", bundle: nil)
//            logViewController.hideDoneButton()
//            navigationController?.pushViewController(logViewController, animated: true)
//            logViewController.hideDoneButton()
//        default:
//            break
//        }
//
//        self.tableView.deselectRow(at: indexPath, animated: true)
//        navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(PVSettingsViewController.done(_:))), animated: false)
//    }
//}

#if os(iOS)
@available(iOS 9.0, *)
class ThemeSelectorViewController: UITableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 2 : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

        let currentTheme = Theme.currentTheme

        if indexPath.row == 0 {
            cell.textLabel?.text = Themes.light.rawValue
            cell.accessoryType = currentTheme.theme == .light ? .checkmark : .none
        } else if indexPath.row == 1 {
            cell.textLabel?.text = Themes.dark.rawValue
            cell.accessoryType = currentTheme.theme == .dark ? .checkmark : .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        if indexPath.row == 0 {
//            Theme.currentTheme = Theme.lightTheme
//            PVSettingsModel.shared.theme = .light
//        } else if indexPath.row == 1 {
//            Theme.currentTheme = Theme.darkTheme
//            PVSettingsModel.shared.theme = .dark
//        }

        tableView.reloadData()
    }
}
#endif
