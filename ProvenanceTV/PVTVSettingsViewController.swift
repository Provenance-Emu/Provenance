//  PVTVSettingsViewController.swift
//  Provenance
//
//  Created by James Addyman on 18/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import UIKit

class PVTVSettingsViewController: UITableViewController, WebServerActivatorController {
    lazy var gameImporter: PVGameImporter = PVGameImporter()
    @IBOutlet weak var autoSaveValueLabel: UILabel!
    @IBOutlet weak var timedAutoSavesValueLabel: UILabel!
    @IBOutlet weak var timedAutoSavesCell: UITableViewCell!
    @IBOutlet weak var autoLoadValueLabel: UILabel!
    @IBOutlet weak var askToLoadSavesValueLabel: UILabel!
    @IBOutlet weak var versionValueLabel: UILabel!
    @IBOutlet weak var askToLoadSavesCell: UITableViewCell!
    @IBOutlet weak var revisionLabel: UILabel!
    @IBOutlet weak var modeValueLabel: UILabel!
    @IBOutlet weak var showFPSCountValueLabel: UILabel!
    @IBOutlet weak var iCadeControllerSetting: UILabel!
    @IBOutlet weak var crtFilterLabel: UILabel!
    @IBOutlet weak var webDavAlwaysOnValueLabel: UILabel!
    @IBOutlet weak var webDavAlwaysOnTitleLabel: UILabel!
    @IBOutlet weak var imageSmoothingLabel: UILabel!

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
            versionValueLabel.textColor = UIColor.init(hex: "#F5F5A0")
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        splitViewController?.title = "Settings"
        let settings = PVSettingsModel.shared
        iCadeControllerSetting.text = iCadeControllerSettingToString(settings.myiCadeControllerSetting)
        updateWebDavTitleLabel()
    }

    override func viewDidLayoutSubviews() {
        if PVSettingsModel.sharedInstance().autoLoadSaves == true {
            disableAskToLoadSavesCell()
            disableAutoLoadSaves()
        } else {
            enableAskToLoadSavesCell()
        }
        if PVSettingsModel.sharedInstance().autoSave == false {
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
        var firstLineAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 38)]

        if #available(tvOS 10.0, *), traitCollection.userInterfaceStyle == .dark {
            firstLineAttributes[NSAttributedStringKey.foregroundColor] = UIColor.white
        }

        let titleString = NSMutableAttributedString(string: "Web Server Always-On", attributes: firstLineAttributes)
        // Make a new line sub title with instructions to connect in lighter text
        if isAlwaysOn {
            let subTitleText = "\nWebDav: \(PVWebServer.shared.webDavURLString)"

            let subTitleAttributes = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 26), NSAttributedStringKey.foregroundColor: UIColor.gray]
            let subTitleAttrString = NSMutableAttributedString(string: subTitleText, attributes: subTitleAttributes)
            titleString.append(subTitleAttrString)
        }
        webDavAlwaysOnTitleLabel.attributedText = titleString
    }

// MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }

        switch indexPath.section {
        case 0:
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
        case 1:
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
        case 2:
            // Controller
            break
        case 3:
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
                if PVSettingsModel.shared.webDavAlwaysOn && !PVWebServer.shared.isWebDavServerRunning {
                    PVWebServer.shared.startWebDavServer()
                } else if !(PVSettingsModel.shared.webDavAlwaysOn && PVWebServer.shared.isWebDavServerRunning) {
                    PVWebServer.shared.stopWebDavServer()
                }

                // Update the label to hide / show the instructions to connect
                updateWebDavTitleLabel()
            default:
                break
            }
        case 4:
            // Game Library
            switch indexPath.row {
            case 0:
                // Refresh
                let alert = UIAlertController(title: "Refresh Game Library?", message: "Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
                }))
                alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
                present(alert, animated: true) {() -> Void in }
            case 1:
                // Empty Cache
                let alert = UIAlertController(title: "Empty Image Cache?", message: "Empty the image cache to free up disk space. Images will be redownload on demand.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    try? PVMediaCache.empty()
                }))
                alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
                present(alert, animated: true) {() -> Void in }
            case 2:
                let conflictViewController = PVConflictViewController(gameImporter: gameImporter)
                navigationController?.pushViewController(conflictViewController, animated: true)
            default:
                break
            }
        default:
            break
        }
    }

    func disableTimedAutoSaveCell() {
        timedAutoSavesCell.alpha = 0.2
    }

    func disableTimedAutoSaves() {
        if timedAutoSavesValueLabel.text == "ON" {
            TOGGLE_SETTING(\PVSettingsModel.timedAutoSaves, timedAutoSavesValueLabel)
        }
        PVSettingsModel.sharedInstance().timedAutoSaves = false
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
        PVSettingsModel.sharedInstance().askToAutoLoad = false
    }

    func enableAskToLoadSavesCell() {
        askToLoadSavesCell.alpha = 1.0
    }
}

// Reduce code, use a macro!
fileprivate extension Bool {
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
