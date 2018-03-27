//  PVTVSettingsViewController.swift
//  Provenance
//
//  Created by James Addyman on 18/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import UIKit

class PVTVSettingsViewController: UITableViewController {
    var gameImporter: PVGameImporter = PVGameImporter(completionHandler: nil)
    @IBOutlet weak var autoSaveValueLabel: UILabel!
    @IBOutlet weak var autoLoadValueLabel: UILabel!
    @IBOutlet weak var versionValueLabel: UILabel!
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
        autoSaveValueLabel.text = settings.autoSave ? "On" : "Off"
        autoLoadValueLabel.text = settings.autoLoadAutoSaves ? "On" : "Off"
        showFPSCountValueLabel.text = settings.showFPSCount ? "On" : "Off"
        crtFilterLabel.text = settings.crtFilterEnabled ? "On" : "Off"
        imageSmoothingLabel.text = settings.imageSmoothing.onOffString
        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "" ))")
        versionValueLabel.text = versionText
#if DEBUG
        modeValueLabel.text = "DEBUG"
#else
        modeValueLabel.text = "RELEASE"
#endif

        let color = UIColor(white: 0.0, alpha: 0.1)
        if let revisionString = Bundle.main.infoDictionary?["Revision"] as? String, !revisionString.isEmpty {
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

    func updateWebDavTitleLabel() {
        let isAlwaysOn: Bool = PVSettingsModel.shared.webDavAlwaysOn
        // Set the status indicator text
        webDavAlwaysOnValueLabel.text = isAlwaysOn ? "On" : "Off"
        // Use 2 lines if on to make space for the sub title
        webDavAlwaysOnTitleLabel.numberOfLines = isAlwaysOn ? 2 : 1
            // The main title is always present
        var firstLineAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 38)]

        if #available(tvOS 10.0, *), traitCollection.userInterfaceStyle == .dark {
            firstLineAttributes[NSAttributedStringKey.foregroundColor] = UIColor.white
        }

        let titleString = NSMutableAttributedString(string: "Always on WebDav server", attributes: firstLineAttributes)
        // Make a new line sub title with instructions to connect in lighter text
        if isAlwaysOn {
            let subTitleText = "\nPoint a WebDav client to \(PVWebServer.shared.webDavURLString)"

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
                // Emu Settings
                switch indexPath.row {
                    case 0:
                        // Auto save
                        TOGGLE_SETTING(\PVSettingsModel.autoSave, autoSaveValueLabel)
                    case 1:
                        // auto load
                        TOGGLE_SETTING(\PVSettingsModel.autoLoadAutoSaves, autoLoadValueLabel)
                    case 2:
                        // CRT Filter
                        TOGGLE_SETTING(\PVSettingsModel.crtFilterEnabled, crtFilterLabel)
                    case 3:
                    // Image Smoother
                    TOGGLE_SETTING(\PVSettingsModel.imageSmoothing, imageSmoothingLabel)
                    case 4:
                        // FPS Counter
                        TOGGLE_SETTING(\PVSettingsModel.showFPSCount, showFPSCountValueLabel)
                    default:
                        break
                }
            case 1:
                // iCade Settings
                break
            case 2:
                // Actions
                switch indexPath.row {
                    case 0:
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
                    case 1:
                            // Start Webserver
                            // Check to see if we are connected to WiFi. Cannot continue otherwise.
                        let reachability = Reachability.forLocalWiFi()
                        reachability.startNotifier()
                        let status: NetworkStatus = reachability.currentReachabilityStatus()
                        if status != ReachableViaWiFi {
                            let alert = UIAlertController(title: "Unable to start web server!", message: "Your device needs to be connected to a WiFi network to continue!", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                            }))
                            present(alert, animated: true) {() -> Void in }
                        } else {
                            // connected via wifi, let's continue
                            // start web transfer service
                            if PVWebServer.shared.startServers() {
                                    // get the IP address of the device
                                let webServerAddress: String = PVWebServer.shared.urlString
                                let webDavAddress: String = PVWebServer.shared.webDavURLString
                                let message = """
                                    Read Importing ROMs wiki…
                                    Upload/Download files at:

                                    \(webServerAddress)  ᵂᵉᵇᵁᴵ
                                    \(webDavAddress)  ᵂᵉᵇᴰᵃᵛ

                                    """
                                let alert = UIAlertController(title: "Web Server Active", message: message, preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "Stop", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                                    PVWebServer.shared.stopServers()
                                }))
                                present(alert, animated: true) {() -> Void in }
                            } else {
                                    // Display error
                                let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or that something isn't already running on required ports 80 & 81", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                                }))
                                present(alert, animated: true) {() -> Void in }
                            }
                        }
                    default:
                        break
                }
            case 3:
                // Game Library Settings
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
}

// Reduce code, use a macro!
fileprivate extension Bool {
    var onOffString: String {
        return self ? "On" : "Off"
    }
}

private func TOGGLE_SETTING(_ setting: ReferenceWritableKeyPath<PVSettingsModel, Bool>, _ label: UILabel) {
    let currentValue = PVSettingsModel.shared[keyPath: setting]
    let newValue = !currentValue

    PVSettingsModel.shared[keyPath: setting] = newValue
    label.text = newValue.onOffString
}
