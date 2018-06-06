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

// Subclass to help with themeing
@objc public class SettingsTableView: UITableView {
    public override init(frame: CGRect, style: UITableViewStyle) {
        super.init(frame: frame, style: style)
        self.backgroundColor = Theme.currentTheme.settingsHeaderBackground
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = Theme.currentTheme.settingsHeaderBackground
    }
}

class PVSettingsViewController: UITableViewController, SFSafariViewControllerDelegate, WebServerActivatorController {
    @IBOutlet weak var autoSaveSwitch: UISwitch!
    @IBOutlet weak var autoLoadSwitch: UISwitch!
    @IBOutlet weak var timedAutoSavesSwitch: UISwitch!
    @IBOutlet weak var timedAutoSavesCell: UITableViewCell!
    @IBOutlet weak var askToLoadSwitch: UISwitch!
    @IBOutlet weak var askToLoadSavesCell: UITableViewCell!
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
    @IBOutlet weak var tintSwitch: UISwitch!
    @IBOutlet weak var startSelectSwitch: UISwitch!
    @IBOutlet weak var volumeHUDSwitch: UISwitch!
    @IBOutlet weak var allRightShouldersSwitch: UISwitch!
    @IBOutlet weak var themeValueLabel: UILabel!

    var gameImporter: PVGameImporter?

    @IBAction func wikiLinkButton(_ sender: Any) {
		let webVC = WebkitViewController(url: URL(string: "https://github.com/Provenance-Emu/Provenance/wiki/Formatting-ROMs")!)
		navigationController?.pushViewController(webVC, animated: true)
    }

    @IBAction func done(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) {() -> Void in }
    }

	// Check to see if we are connected to WiFi. Cannot continue otherwise.
	lazy var reachability : Reachability = Reachability.forLocalWiFi()

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		reachability.stopNotifier()
	}

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        let settings = PVSettingsModel.shared
        autoSaveSwitch.isOn = settings.autoSave
        timedAutoSavesSwitch.isOn = settings.timedAutoSaves
        autoLoadSwitch.isOn = settings.autoLoadSaves
        askToLoadSwitch.isOn = settings.askToAutoLoad
        opacitySlider.value = Float(settings.controllerOpacity)
        autoLockSwitch.isOn = settings.disableAutoLock
        vibrateSwitch.isOn = settings.buttonVibration
        imageSmoothing.isOn = settings.imageSmoothing
        crtFilterSwitch.isOn = settings.crtFilterEnabled
        fpsCountSwitch.isOn = settings.showFPSCount
        tintSwitch.isOn = settings.buttonTints
        startSelectSwitch.isOn = settings.startSelectAlwaysOn
        allRightShouldersSwitch.isOn = settings.allRightShoulders
        volumeHUDSwitch.isOn = settings.volumeHUD
        volumeSlider.value = settings.volume
        volumeValueLabel.text = String(format: "%.0f%%", volumeSlider.value * 100)
        opacityValueLabel.text = String(format: "%.0f%%", opacitySlider.value * 100)

        let masterBranch = kGITBranch.lowercased() == "master"

        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        if !masterBranch {
            versionText = "\(versionText ?? "") Beta"
            versionLabel.textColor = UIColor.init(hex: "#F5F5A0")
        }

        versionLabel.text = versionText
#if DEBUG
        modeLabel.text = "DEBUG"
#else
        modeLabel.text = "RELEASE"
#endif
        let color: UIColor? = UIColor(white: 0.0, alpha: 0.1)
        if var revisionString = Bundle.main.infoDictionary?["Revision"] as? String, !revisionString.isEmpty {
            if !masterBranch {
                revisionString = "\(kGITBranch)/\(revisionString)"
            }
            revisionLabel.text = revisionString
        } else {
            revisionLabel.textColor = color ?? UIColor.clear
            revisionLabel.text = "(none)"
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

		reachability.startNotifier()

        let settings = PVSettingsModel.shared
        iCadeControllerSetting.text = iCadeControllerSettingToString(settings.myiCadeControllerSetting)

        if #available(iOS 9.0, *) {
            themeValueLabel.text = settings.theme.rawValue
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        // placed for animation use later…
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

    @IBAction func help(_ sender: Any) {
		let webVC = WebkitViewController(url: URL(string: "https://github.com/Provenance-Emu/Provenance/wiki")!)
		navigationController?.pushViewController(webVC, animated: true)
    }

    @IBAction func toggleFPSCount(_ sender: Any) {
        PVSettingsModel.shared.showFPSCount = fpsCountSwitch.isOn
    }

    @IBAction func toggleAutoSave(_ sender: Any) {
        PVSettingsModel.shared.autoSave = autoSaveSwitch.isOn
        if autoSaveSwitch.isOn {
            UIView.animate(withDuration: 0.5, animations: {
                self.enableTimedAutoSavesCell()
            }, completion: nil)
        } else {
            UIView.animate(withDuration: 0.5, animations: {
                self.disableTimedAutoSaveCell()
            }, completion: nil)
            disableTimedAutoSaves()
        }
    }

    @IBAction func toggleAutoLoadSaves(_ sender: Any) {
        PVSettingsModel.shared.autoLoadSaves = autoLoadSwitch.isOn
        if autoLoadSwitch.isOn {
            UIView.animate(withDuration: 0.5, animations: {
                self.disableAskToLoadSavesCell()
            }, completion: nil)
            disableAutoLoadSaves()
        } else {
            UIView.animate(withDuration: 0.5, animations: {
                self.enableAskToLoadSavesCell()
            }, completion: nil)
        }
    }

    @IBAction func toggleTimedAutoSaves(_ sender: Any) {
        PVSettingsModel.shared.timedAutoSaves = timedAutoSavesSwitch.isOn
    }

    @IBAction func toggleAskToLoadSaves(_ sender: Any) {
        PVSettingsModel.shared.askToAutoLoad = askToLoadSwitch.isOn
    }

    @IBAction func controllerOpacityChanged(_ sender: Any) {
        opacitySlider.value = floor(opacitySlider.value / Float(0.05)) * Float(0.05)
        opacityValueLabel.text = String(format: "%.0f%%", opacitySlider.value * Float(100.0))
        PVSettingsModel.shared.controllerOpacity = CGFloat(opacitySlider.value)
    }

    @IBAction func toggleAutoLock(_ sender: Any) {
        PVSettingsModel.shared.disableAutoLock = autoLockSwitch.isOn
    }

    @IBAction func toggleVibration(_ sender: Any) {
        PVSettingsModel.shared.buttonVibration = vibrateSwitch.isOn
    }

    @IBAction func toggleSmoothing(_ sender: Any) {
        PVSettingsModel.shared.imageSmoothing = imageSmoothing.isOn
    }

    @IBAction func toggleCRTFilter(_ sender: Any) {
        PVSettingsModel.shared.crtFilterEnabled = crtFilterSwitch.isOn
    }

    @IBAction func volumeChanged(_ sender: Any) {
        PVSettingsModel.shared.volume = volumeSlider.value
        volumeValueLabel.text = String(format: "%.0f%%", volumeSlider.value * 100)
    }

    @IBAction func toggleButtonTints(_ sender: Any) {
        PVSettingsModel.sharedInstance().buttonTints = tintSwitch.isOn
    }

    @IBAction func toggleStartSelectAlwaysOn(_ sender: Any) {
        PVSettingsModel.sharedInstance().startSelectAlwaysOn = startSelectSwitch.isOn
    }

    @IBAction func toggleVolumeHUD(_ sender: Any) {
        PVSettingsModel.sharedInstance().volumeHUD = volumeHUDSwitch.isOn
    }

    @IBAction func toggleAllRightShoulders(_ sender: Any) {
        PVSettingsModel.sharedInstance().allRightShoulders = allRightShouldersSwitch.isOn
    }

    func disableTimedAutoSaveCell() {
        timedAutoSavesCell.alpha = 0.5
        timedAutoSavesSwitch.isEnabled = false
    }

    func disableTimedAutoSaves() {
        timedAutoSavesSwitch.setOn(false, animated: true)
        PVSettingsModel.sharedInstance().timedAutoSaves = false
    }

    func enableTimedAutoSavesCell() {
        timedAutoSavesCell.alpha = 1.0
        timedAutoSavesSwitch.isEnabled = true
    }

    func disableAskToLoadSavesCell() {
        askToLoadSavesCell.alpha = 0.5
        askToLoadSwitch.isEnabled = false
    }

    func disableAutoLoadSaves() {
        askToLoadSwitch.setOn(false, animated: true)
        PVSettingsModel.sharedInstance().askToAutoLoad = false
    }

    func enableAskToLoadSavesCell() {
        askToLoadSavesCell.alpha = 1.0
        askToLoadSwitch.isEnabled = true
    }

    // Show web server (stays on)
    @available(iOS 9.0, *)
    func showServer() {
        let ipURL: String = PVWebServer.shared.urlString
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
        PVWebServer.shared.stopServers()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 3 && indexPath.row == 0 {
            // import/export roms and game saves button
            tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)

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
        } else if indexPath.section == 4 && indexPath.row == 0 {
            tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
            let alert = UIAlertController(title: "Refresh Game Library?", message: "Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                NotificationCenter.default.post(name: NSNotification.Name.PVRefreshLibrary, object: nil)
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            present(alert, animated: true) {() -> Void in }
        } else if indexPath.section == 4 && indexPath.row == 1 {
            tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0), animated: true)
            let alert = UIAlertController(title: "Empty Image Cache?", message: "Empty the image cache to free up disk space. Images will be redownload on demand.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                try? PVMediaCache.empty()
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            present(alert, animated: true) {() -> Void in }
        } else if indexPath.section == 4 && indexPath.row == 2 {
            if let gameImporter = gameImporter {
                let conflictViewController = PVConflictViewController(gameImporter: gameImporter)
                navigationController?.pushViewController(conflictViewController, animated: true)
            } else {
                ELOG("No game importer instance")
            }
        } else if indexPath.section == 0 && indexPath.row == 8 {
            if #available(iOS 9.0, *) {
                let themeSelectorViewController = ThemeSelectorViewController()
                navigationController?.pushViewController(themeSelectorViewController, animated: true)
            } else {
                let alert = UIAlertController(title: "Not Available", message: "Themes are only available in iOS 9 and above.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
		} else if indexPath.section == 6 && indexPath.row == 2 {
			// Log Viewer
			let logViewController = PVLogViewController(nibName: "PVLogViewController", bundle: nil)
			logViewController.hideDoneButton()
			navigationController?.pushViewController(logViewController, animated: true)
			logViewController.hideDoneButton()
		}

        self.tableView.deselectRow(at: indexPath, animated: true)
        navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(PVSettingsViewController.done(_:))), animated: false)
    }
}

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
        if indexPath.row == 0 {
            Theme.currentTheme = Theme.lightTheme
            PVSettingsModel.shared.theme = .light
        } else if indexPath.row == 1 {
            Theme.currentTheme = Theme.darkTheme
            PVSettingsModel.shared.theme = .dark
        }

        tableView.reloadData()
    }
}
