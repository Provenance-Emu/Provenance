//  PVTVSettingsViewController.swift
//  Provenance
//
//  Created by James Addyman on 18/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import UIKit

final class PVTVSettingsViewController: UITableViewController, WebServerActivatorController {
    lazy var gameImporter: GameImporter = GameImporter.shared
    @IBOutlet var autoSaveValueLabel: UILabel!
    @IBOutlet var timedAutoSavesValueLabel: UILabel!
    @IBOutlet var timedAutoSavesCell: UITableViewCell!
    @IBOutlet var autoLoadValueLabel: UILabel!
    @IBOutlet var askToLoadSavesValueLabel: UILabel!
    @IBOutlet var versionValueLabel: UILabel!
    @IBOutlet var askToLoadSavesCell: UITableViewCell!
    @IBOutlet var revisionLabel: UILabel!
    @IBOutlet var modeValueLabel: UILabel!
    @IBOutlet var showFPSCountValueLabel: UILabel!
    @IBOutlet var iCadeControllerSetting: UILabel!
    @IBOutlet var crtFilterLabel: UILabel!
    @IBOutlet var webDavAlwaysOnValueLabel: UILabel!
    @IBOutlet var webDavAlwaysOnTitleLabel: UILabel!
    @IBOutlet var imageSmoothingLabel: UILabel!
    @IBOutlet var bundleIDLabel: UILabel!
    @IBOutlet var builderLabel: UILabel!
    @IBOutlet var buildDateLabel: UILabel!
    @IBOutlet var buildNumberLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.title = "Settings"
        tableView.backgroundView = nil
        tableView.backgroundColor = UIColor.clear

        let settings = PVSettingsModel.shared
        autoSaveValueLabel.text = settings.autoSave ? "ON" : "OFF"
        timedAutoSavesValueLabel.text = settings.timedAutoSaves ? "ON" : "OFF"
        autoLoadValueLabel.text = settings.autoLoadSaves ? "ON" : "OFF"
        askToLoadSavesValueLabel.text = settings.askToAutoLoad ? "ON" : "OFF"
        showFPSCountValueLabel.text = settings.showFPSCount ? "ON" : "OFF"
        crtFilterLabel.text = settings.crtFilterEnabled ? "ON" : "OFF"
        imageSmoothingLabel.text = settings.imageSmoothing.onOffString

        let masterBranch = kGITBranch.lowercased() == "master"

        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        if !masterBranch {
            versionText = "\(versionText ?? "") Beta"
            versionValueLabel.textColor = UIColor(hex: "#F5F5A0")
        }
        versionValueLabel.text = versionText

        #if DEBUG
            modeValueLabel.text = "DEBUG"
        #else
            modeValueLabel.text = "RELEASE"
        #endif

        let color = UIColor(white: 0.0, alpha: 0.1)
        if var revisionString = Bundle.main.infoDictionary?["Revision"] as? String, !revisionString.isEmpty {
            if !masterBranch {
                revisionString = "\(kGITBranch)/\(revisionString)"
            }
            revisionLabel.text = revisionString
        } else {
            revisionLabel.textColor = color
            revisionLabel.text = "(none)"
        }

        buildNumberLabel.text = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "nil"

        let incomingDateFormatter = DateFormatter()
        incomingDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        incomingDateFormatter.dateFormat = "E MMM d HH:mm:ss yyyy"

        let outputDateFormatter = DateFormatter()
        outputDateFormatter.dateFormat = "MM/dd/yyyy hh:mm a"

        var buildDate = Date(timeIntervalSinceReferenceDate: 0)
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

        buildDateLabel.text = outputDateFormatter.string(from: buildDate)
        bundleIDLabel.text = Bundle.main.bundleIdentifier
        builderLabel.text = builtByUser
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        splitViewController?.title = "Settings"
        let settings = PVSettingsModel.shared
        iCadeControllerSetting.text = settings.myiCadeControllerSetting.description
        updateWebDavTitleLabel()
    }

    override func viewDidLayoutSubviews() {
        if PVSettingsModel.shared.autoLoadSaves == true {
            disableAskToLoadSavesCell()
            disableAutoLoadSaves()
        } else {
            enableAskToLoadSavesCell()
        }
        if PVSettingsModel.shared.autoSave == false {
            disableTimedAutoSaveCell()
            disableTimedAutoSaves()
        } else {
            enableTimedAutoSavesCell()
        }
    }

    func updateWebDavTitleLabel() {
        let isAlwaysOn: Bool = PVSettingsModel.shared.webDavAlwaysOn
        // Set the status indicator text
        webDavAlwaysOnValueLabel.text = isAlwaysOn ? "ON" : "OFF"
        // Use 2 lines if on to make space for the sub title
        webDavAlwaysOnTitleLabel.numberOfLines = isAlwaysOn ? 2 : 1
        // The main title is always present
        var firstLineAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 38)]

        if #available(tvOS 10.0, *), traitCollection.userInterfaceStyle == .dark {
            firstLineAttributes[NSAttributedString.Key.foregroundColor] = UIColor.white
        }

        let titleString = NSMutableAttributedString(string: "Web Server Always-On", attributes: firstLineAttributes)
        // Make a new line sub title with instructions to connect in lighter text
        if isAlwaysOn {
            let subTitleText = "\nWebDav: \(PVWebServer.shared.webDavURLString)"

            let subTitleAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 26), NSAttributedString.Key.foregroundColor: UIColor.gray]
            let subTitleAttrString = NSMutableAttributedString(string: subTitleText, attributes: subTitleAttributes)
            titleString.append(subTitleAttrString)
        }
        webDavAlwaysOnTitleLabel.attributedText = titleString
    }

    private struct Selections {
        enum Sections: Int {
            case app
            case saves
            case audioVideo
            case controller
            case gameLibrary
            case gameLibrary2
            case buildInformation
            case externalInformation
        }

        static let launchWebServer = IndexPath(row: 0, section: Sections.gameLibrary.rawValue)

        static let refreshGameLibrary = IndexPath(row: 0, section: Sections.gameLibrary2.rawValue)
        static let emptyImageCache = IndexPath(row: 1, section: Sections.gameLibrary2.rawValue)
        static let manageConflicts = IndexPath(row: 2, section: Sections.gameLibrary2.rawValue)
        static let appearance = IndexPath(row: 3, section: Sections.gameLibrary2.rawValue)

        static let cores = IndexPath(row: 0, section: Sections.gameLibrary2.rawValue)
        static let licenses = IndexPath(row: 1, section: Sections.gameLibrary2.rawValue)

        static let h = IndexPath(row: 0, section: Sections.gameLibrary2.rawValue)
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }

        let section = Selections.Sections(rawValue: indexPath.section)!
        switch section {
        case .app, .controller, .buildInformation, .externalInformation:
            break
        case .saves:
            // Settings
            switch indexPath.row {
            case 0:
                // Auto Save
                TOGGLE_SETTING(\PVSettingsModel.autoSave, autoSaveValueLabel)
                if autoSaveValueLabel.text == "ON" {
                    UIView.animate(withDuration: 0.5, animations: {
                        self.enableTimedAutoSavesCell()
                    }, completion: nil)
                } else {
                    UIView.animate(withDuration: 0.5, animations: {
                        self.disableTimedAutoSaveCell()
                    }, completion: nil)
                    disableTimedAutoSaves()
                }
            case 1:
                // Timed Auto Saves
                if timedAutoSavesCell.alpha == 1.0 {
                    TOGGLE_SETTING(\PVSettingsModel.timedAutoSaves, timedAutoSavesValueLabel)
                }
            case 2:
                // Auto Load Saves
                TOGGLE_SETTING(\PVSettingsModel.autoLoadSaves, autoLoadValueLabel)
                if autoLoadValueLabel.text == "ON" {
                    UIView.animate(withDuration: 0.5, animations: {
                        self.disableAskToLoadSavesCell()
                    }, completion: nil)
                    disableAutoLoadSaves()
                } else {
                    UIView.animate(withDuration: 0.5, animations: {
                        self.enableAskToLoadSavesCell()
                    }, completion: nil)
                }
            case 3:
                // Ask to Load Saves
                if askToLoadSavesCell.alpha == 1.0 {
                    TOGGLE_SETTING(\PVSettingsModel.askToAutoLoad, askToLoadSavesValueLabel)
                }
            default:
                break
            }
        case .audioVideo:
            // Audio/Video
            switch indexPath.row {
            case 0:
                // CRT Filter
                TOGGLE_SETTING(\PVSettingsModel.crtFilterEnabled, crtFilterLabel)
            case 1:
                // Image Smoother
                TOGGLE_SETTING(\PVSettingsModel.imageSmoothing, imageSmoothingLabel)
            case 2:
                // FPS Counter
                TOGGLE_SETTING(\PVSettingsModel.showFPSCount, showFPSCountValueLabel)
            default:
                break
            }
        case .gameLibrary:
            // Game Library
            switch indexPath.row {
            case 0:
                // Web Server
                showServerActiveAlert()
            case 1:
                PVSettingsModel.shared.webDavAlwaysOn = !PVSettingsModel.shared.webDavAlwaysOn
                // Always on WebDav server
                // Currently this is only exposed on ATV since it would be a drain on battery
                // for a mobile device to have this on and doesn't seem nearly as useful.
                // Web dav can still be manually started alone side the web server
                if PVSettingsModel.shared.webDavAlwaysOn, !PVWebServer.shared.isWebDavServerRunning {
                    PVWebServer.shared.startWebDavServer()
                } else if !(PVSettingsModel.shared.webDavAlwaysOn && PVWebServer.shared.isWebDavServerRunning) {
                    PVWebServer.shared.stopWebDavServer()
                }

                // Update the label to hide / show the instructions to connect
                updateWebDavTitleLabel()
            default:
                break
            }
        case .gameLibrary2:
            // Game Library
            switch indexPath.row {
            case 0:
                // Refresh
                let alert = UIAlertController(title: "Refresh Game Library?", message: "Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_: UIAlertAction) -> Void in
                    NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
                }))
                alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
                present(alert, animated: true) { () -> Void in }
            case 1:
                // Empty Cache
                let alert = UIAlertController(title: "Empty Image Cache?", message: "Empty the image cache to free up disk space. Images will be redownload on demand.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_: UIAlertAction) -> Void in
                    try? PVMediaCache.empty()
                }))
                alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
                present(alert, animated: true) { () -> Void in }
            case 2:
                let conflictViewController = PVConflictViewController(gameImporter: gameImporter)
                navigationController?.pushViewController(conflictViewController, animated: true)
            default:
                break
            }
        }
    }

    func disableTimedAutoSaveCell() {
        timedAutoSavesCell.alpha = 0.2
    }

    func disableTimedAutoSaves() {
        if timedAutoSavesValueLabel.text == "ON" {
            TOGGLE_SETTING(\PVSettingsModel.timedAutoSaves, timedAutoSavesValueLabel)
        }
        PVSettingsModel.shared.timedAutoSaves = false
    }

    func enableTimedAutoSavesCell() {
        timedAutoSavesCell.alpha = 1.0
    }

    func disableAskToLoadSavesCell() {
        askToLoadSavesCell.alpha = 0.2
    }

    func disableAutoLoadSaves() {
        if askToLoadSavesValueLabel.text == "ON" {
            TOGGLE_SETTING(\PVSettingsModel.askToAutoLoad, askToLoadSavesValueLabel)
        }
        PVSettingsModel.shared.askToAutoLoad = false
    }

    func enableAskToLoadSavesCell() {
        askToLoadSavesCell.alpha = 1.0
    }
}

// Reduce code, use a macro!
private extension Bool {
    var onOffString: String {
        return self ? "ON" : "OFF"
    }
}

private func TOGGLE_SETTING(_ setting: ReferenceWritableKeyPath<PVSettingsModel, Bool>, _ label: UILabel) {
    let currentValue = PVSettingsModel.shared[keyPath: setting]
    let newValue = !currentValue

    PVSettingsModel.shared[keyPath: setting] = newValue
    label.text = newValue.onOffString
}
