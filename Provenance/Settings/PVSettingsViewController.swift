//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVSettingsViewController.swift
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import SafariServices
import UIKit

class PVSettingsViewController: UITableViewController, SFSafariViewControllerDelegate {
    @IBOutlet weak var autoSaveSwitch: UISwitch!
    @IBOutlet weak var autoLoadSwitch: UISwitch!
    @IBOutlet weak var autoLockSwitch: UISwitch!
    @IBOutlet weak var vibrateSwitch: UISwitch!
    @IBOutlet weak var imageSmoothing: UISwitch!
    @IBOutlet weak var crtFilterSwitch: UISwitch!
    @IBOutlet weak var opacitySlider: UISlider!
    @IBOutlet weak var opacityValueLabel: UILabel!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var revisionLabel: UILabel!
    @IBOutlet weak var modeLabel: UILabel!
    @IBOutlet weak var iCadeControllerSetting: UILabel!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var volumeValueLabel: UILabel!
    @IBOutlet weak var fpsCountSwitch: UISwitch!
    @IBOutlet weak var importLabel: UILabel!
    
    @IBOutlet weak var themeValueLabel: UILabel!
    
    
    var gameImporter: PVGameImporter?

    @IBAction func wikiLinkButton(_ sender: Any) {
        UIApplication.shared.openURL((URL(string: "https://github.com/jasarien/Provenance/wiki/Importing-ROMs"))!)
    }

    @IBAction func done(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) {() -> Void in }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        let settings = PVSettingsModel.sharedInstance()
        autoSaveSwitch.isOn = settings.autoSave
        autoLoadSwitch.isOn = settings.autoLoadAutoSaves
        opacitySlider.value = Float(settings.controllerOpacity)
        autoLockSwitch.isOn = settings.disableAutoLock
        vibrateSwitch.isOn = settings.buttonVibration
        imageSmoothing.isOn = settings.imageSmoothing
        crtFilterSwitch.isOn = settings.crtFilterEnabled
        fpsCountSwitch.isOn = settings.showFPSCount
        volumeSlider.value = settings.volume
        volumeValueLabel.text = String(format: "%.0f%%", volumeSlider.value * 100)
        opacityValueLabel.text = String(format: "%.0f%%", opacitySlider.value * 100)
        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        versionLabel.text = versionText
    
#if DEBUG
        modeLabel.text = "DEBUG"
#else
        modeLabel.text = "RELEASE"
#endif
        let color: UIColor? = UIColor(white: 0.0, alpha: 0.1)
        if let revisionString = Bundle.main.infoDictionary?["Revision"] as? String, !revisionString.isEmpty {
            revisionLabel.text = revisionString
        }
        else {
            revisionLabel.textColor = color ?? UIColor.clear
            revisionLabel.text = "(none)"
        }
    }

    //Hide Dummy Cell Separator
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == 1 && indexPath.section == 4 {
            cell.separatorInset = UIEdgeInsetsMake(0, cell.bounds.size.width, 0, 0)
        }
        else if indexPath.row == 2 && indexPath.section == 4 {
            cell.isHidden = true
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let settings = PVSettingsModel.sharedInstance()
        iCadeControllerSetting.text = kIcadeControllerSettingToString(settings.iCadeControllerSetting)
        
        if #available(iOS 9.0, *) {
            themeValueLabel.text = settings.theme.rawValue
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        // placed for animation use later…
    }

    @IBAction func help(_ sender: Any) {
        UIApplication.shared.openURL((URL(string: "https://github.com/jasarien/Provenance/wiki"))!)
    }

    @IBAction func toggleFPSCount(_ sender: Any) {
        PVSettingsModel.sharedInstance().showFPSCount = fpsCountSwitch.isOn
    }

    @IBAction func toggleAutoSave(_ sender: Any) {
        PVSettingsModel.sharedInstance().autoSave = autoSaveSwitch.isOn
    }

    @IBAction func toggleAutoLoadAutoSaves(_ sender: Any) {
        PVSettingsModel.sharedInstance().autoLoadAutoSaves = autoLoadSwitch.isOn
    }

    @IBAction func controllerOpacityChanged(_ sender: Any) {
        opacitySlider.value = floor(opacitySlider.value / 0.05) * 0.05
        opacityValueLabel.text = String(format: "%.0f%%", opacitySlider.value * 100)
        PVSettingsModel.sharedInstance().controllerOpacity = CGFloat(opacitySlider.value)
    }

    @IBAction func toggleAutoLock(_ sender: Any) {
        PVSettingsModel.sharedInstance().disableAutoLock = autoLockSwitch.isOn
    }

    @IBAction func toggleVibration(_ sender: Any) {
        PVSettingsModel.sharedInstance().buttonVibration = vibrateSwitch.isOn
    }

    @IBAction func toggleSmoothing(_ sender: Any) {
        PVSettingsModel.sharedInstance().imageSmoothing = imageSmoothing.isOn
    }

    @IBAction func toggleCRTFilter(_ sender: Any) {
        PVSettingsModel.sharedInstance().crtFilterEnabled = crtFilterSwitch.isOn
    }

    @IBAction func volumeChanged(_ sender: Any) {
        PVSettingsModel.sharedInstance().volume = volumeSlider.value
        volumeValueLabel.text = String(format: "%.0f%%", volumeSlider.value * 100)
    }

    // Show web server (stays on)
    @available(iOS 9.0, *)
    func showServer() {
        let ipURL: String = PVWebServer.sharedInstance().urlString
        let safariVC = SFSafariViewController(url: URL(string: ipURL)!, entersReaderIfAvailable: false)
        safariVC.delegate = self
        present(safariVC, animated: true) {() -> Void in }
    }

    @available(iOS 9.0, *)
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        // Load finished
    }

    // Dismiss and shut down web server
    @available(iOS 9.0, *)
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // Done button pressed
        navigationController?.popViewController(animated: true)
        PVWebServer.sharedInstance().stopServers()
        importLabel.text = "Web server: OFF"
    }

    // Show "Web Server Active" alert view
    func showServerActiveAlert() {
        let message = """
            Upload/Download ROMs,
            saves and cover art at:
            
            """
        let alert = UIAlertController(title: "Web Server Active", message: message, preferredStyle: .alert)
        let ipField = UITextView(frame: CGRect(x: 20, y: 71, width: 231, height: 70))
        ipField.backgroundColor = UIColor.clear
        ipField.textAlignment = .center
        ipField.font = UIFont.systemFont(ofSize: 13)
        ipField.textColor = UIColor.gray
        let ipFieldText = "\(PVWebServer.sharedInstance().urlString)\nWebDav: \(PVWebServer.sharedInstance().webDavURLString)"
        ipField.text = ipFieldText
        ipField.isUserInteractionEnabled = false
        alert.view.addSubview(ipField)
        let importNote = UITextView(frame: CGRect(x: 2, y: 160, width: 267, height: 44))
        importNote.isUserInteractionEnabled = false
        importNote.font = UIFont.boldSystemFont(ofSize: 12)
        importNote.textColor = UIColor.white
        importNote.textAlignment = .center
        importNote.backgroundColor = UIColor(white: 0.2, alpha: 0.3)
        importNote.text = "Check the wiki for information about Importing ROMs."
        importNote.layer.shadowOpacity = 0.8
        importNote.layer.shadowRadius = 3.0
        importNote.layer.cornerRadius = 8.0
        importNote.layer.shadowColor = UIColor(white: 0.2, alpha: 0.7).cgColor
        importNote.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        alert.view.addSubview(importNote)
        alert.addAction(UIAlertAction(title: "Stop", style: .cancel, handler: {(_ action: UIAlertAction) -> Void in
            PVWebServer.sharedInstance().stopServers()
            self.importLabel.text = "Web server: OFF"
        }))
        
        if #available(iOS 9.0, *) {
            let viewAction = UIAlertAction(title: "View", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    self.showServer()
                })
            alert.addAction(viewAction)
        }
        present(alert, animated: true) {() -> Void in }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 3 && indexPath.row == 0 {
            let iCadeControllerViewController = PViCadeControllerViewController()
            navigationController?.pushViewController(iCadeControllerViewController, animated: true)
        }
        else if indexPath.section == 4 && indexPath.row == 0 {
            // import/export roms and game saves button
            tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
                // Check to see if we are connected to WiFi. Cannot continue otherwise.
            let reachability = Reachability.forLocalWiFi()
            reachability.startNotifier()
            let status: NetworkStatus = reachability.currentReachabilityStatus()
            if status != ReachableViaWiFi {
                let alert = UIAlertController(title: "Unable to start web server!", message: "Your device needs to be connected to a WiFi network to continue!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                }))
                present(alert, animated: true) {() -> Void in }
            }
            else {
                // connected via wifi, let's continue
                // start web transfer service
                if PVWebServer.sharedInstance().startServers() {
                    importLabel.text = "Web server: ON"
                    //show alert view
                    showServerActiveAlert()
                }
                else {
                        // Display error
                    let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or that something isn't already running on required ports 80 & 81", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    }))
                    present(alert, animated: true) {() -> Void in }
                }
            }
        }
        else if indexPath.section == 5 && indexPath.row == 0 {
            tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
            let alert = UIAlertController(title: "Refresh Game Library?", message: "Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            present(alert, animated: true) {() -> Void in }
        }
        else if indexPath.section == 5 && indexPath.row == 1 {
            tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
            let alert = UIAlertController(title: "Empty Image Cache?", message: "Empty the image cache to free up disk space. Images will be redownload on demand.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                try? PVMediaCache.empty()
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            present(alert, animated: true) {() -> Void in }
        }
        else if indexPath.section == 5 && indexPath.row == 2 {
            if let gameImporter = gameImporter {
                let conflictViewController = PVConflictViewController(gameImporter: gameImporter)
                navigationController?.pushViewController(conflictViewController, animated: true)
            } else {
                ELOG("No game importer instance")
            }
        }
        else if indexPath.section == 7 && indexPath.row == 0 {
            let licensesViewController = PVLicensesViewController()
            navigationController?.pushViewController(licensesViewController, animated: true)
        }
        else if indexPath.section == 0 && indexPath.row == 8 {
            if #available(iOS 9.0, *) {
                let themeSelectorViewController = ThemeSelectorViewController()
                navigationController?.pushViewController(themeSelectorViewController, animated: true)
            } else {
                let alert = UIAlertController(title: "Not Available", message: "Themes are only available in iOS 9 and above.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }

        self.tableView.deselectRow(at: indexPath, animated: true)
        navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(PVSettingsViewController.done(_:))), animated: false)
    }
}

@available(iOS 9.0, *)
class ThemeSelectorViewController : UITableViewController {
    
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
        if indexPath.row == 0 {
            Theme.setTheme(LightTheme())
            PVSettingsModel.sharedInstance().theme = .light
        } else if indexPath.row == 1 {
            Theme.setTheme(DarkTheme())
            PVSettingsModel.sharedInstance().theme = .dark
        }
        
        tableView.reloadData()
    }
}
