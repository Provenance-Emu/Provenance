//
//  WebServerActivatorController.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 5/29/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#if canImport(PVWebServer)
import PVWebServer

import PVLibrary
import PVSupport
import Reachability

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Wiki / alert message (shared)

/// Builds the standard “wiki + URLs” body used in Web Server Active alerts.
enum PVWebServerAlertMessageBuilder {
    static func wikiMessage(http: String, dav: String) -> String {
        """
        Read about how to import ROMs on the Provenance wiki at:
        https://wiki.provenance-emu.com

        Upload/Download files to your device at:

        \(http)  ᵂᵉᵇᵁᴵ
        \(dav)  ᵂᵉᵇᴰᴬⱽ
        """
    }

    static func wikiMessageFromManager() async -> String {
        let http = await PVWebServerManager.shared.serverURL?.absoluteString ?? "null"
        let dav = await PVWebServerManager.shared.webDAVURL?.absoluteString ?? "null"
        return wikiMessage(http: http, dav: dav)
    }
}

#if canImport(SafariServices)
extension PVSettingsViewController: WebServerActivatorController, SFSafariViewControllerDelegate {}
#else
extension PVSettingsViewController: WebServerActivatorController {}
#endif

#if os(iOS)
import SafariServices

extension WebServerActivatorController where Self: UIViewController & SFSafariViewControllerDelegate {
    // Show "Web Server Active" alert view
    public func showServerActiveAlert(sender: UIView?, barButtonItem: UIBarButtonItem?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let message = await PVWebServerAlertMessageBuilder.wikiMessageFromManager()
            let alert = UIAlertController(title: "Web Server Active", message: message, preferredStyle: .alert)
            alert.popoverPresentationController?.barButtonItem = barButtonItem
            alert.popoverPresentationController?.sourceView = sender
            alert.popoverPresentationController?.sourceRect = sender?.bounds ?? UIScreen.main.bounds
            alert.preferredContentSize = CGSize(width: 300, height: 150)
            alert.addAction(UIAlertAction(title: "Stop", style: .cancel, handler: { (_: UIAlertAction) -> Void in
                Task { await PVWebServerManager.shared.stop() }
                Task {
                    let importQueue = await GameImporter.shared.importQueue
                    if importQueue.count > 0 {
                        DLOG("safariViewControllerDidFinish, there are imports in the queue, presenting ImportStatusView")
                        DispatchQueue.main.async { [weak self] in
                            (self as? PVMenuDelegate)?.didTapImports()
                        }
                    }
                }
            }))
            let viewAction = UIAlertAction(title: "View", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.showServer()
            })
            alert.addAction(viewAction)
            alert.addAction(UIAlertAction(title: "Hide (Server Continues Running)", style: .default, handler: { (_: UIAlertAction) -> Void in
            }))
            alert.preferredAction = alert.actions[alert.actions.count - 2]
            self.present(alert, animated: true) { () -> Void in }
        }
    }

    func showServer() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let ipURL = await PVWebServerManager.shared.serverURL?.absoluteString else {
                return
            }
            let url = URL(string: ipURL)!
#if targetEnvironment(macCatalyst) || os(macOS)
            UIApplication.shared.open(url, options: [:]) { completed in
                ILOG("Completed: \(completed ? "Yes":"No")")
            }
#else
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = false
            let safariVC = SFSafariViewController(url: url, configuration: config)
            safariVC.delegate = self
            self.present(safariVC, animated: true) { () -> Void in }
#endif
        }
    }
}
#endif // os(iOS)

#if os(tvOS)
public
typealias WebServerActivatorControllerRootClass = UIViewController
#else
public
typealias WebServerActivatorControllerRootClass = PVGameLibraryViewController
#endif

public
extension WebServerActivatorController where Self: WebServerActivatorControllerRootClass {

    func showServerActiveAlert(sender: UIView?, barButtonItem: UIBarButtonItem?) {
        let reachability = try! Reachability()

        do {
            try reachability.startNotifier()
        } catch {
            ELOG("Failed to start reachability: \(error.localizedDescription)")
        }

        if reachability.connection == .wifi {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await PVWebServerManager.shared.refreshFeatureFlag()
                do {
                    let ok = try await PVWebServerManager.shared.start()
                    if ok {
                        let message = await PVWebServerAlertMessageBuilder.wikiMessageFromManager()
                        let alert = UIAlertController(title: "Web Server Active", message: message, preferredStyle: .alert)
                        alert.preferredContentSize = CGSize(width: 300, height: 150)
#if !os(tvOS)
                        alert.popoverPresentationController?.barButtonItem = barButtonItem
                        alert.popoverPresentationController?.sourceView = sender
                        alert.popoverPresentationController?.sourceRect = sender?.bounds ?? UIScreen.main.bounds
#endif
                        alert.addAction(UIAlertAction(title: "Stop", style: .cancel, handler: { (_: UIAlertAction) -> Void in
                            Task { await PVWebServerManager.shared.stop() }
                        }))
#if os(iOS)
                        let viewAction = UIAlertAction(title: "View", style: .default, handler: { (_: UIAlertAction) -> Void in
                            self.showServer()
                        })
                        alert.addAction(viewAction)
                        alert.addAction(UIAlertAction(title: "Hide (Server Continues Running)", style: .default, handler: { (_: UIAlertAction) -> Void in
                        }))
                        alert.preferredAction = alert.actions[alert.actions.count - 2]
#else
                        alert.preferredAction = alert.actions.last
#endif
                        self.present(alert, animated: true) {
                            Task { @MainActor in
                                alert.message = await PVWebServerAlertMessageBuilder.wikiMessageFromManager()
                            }
                        }
                    } else {
                        let message = """
                        Could not start the web server. Try these steps:

                        1. Make sure your device is connected to Wi-Fi
                        2. Check that ports 80 and 81 are not in use by other apps
                        3. Restart the app and try again
                        4. If the problem persists, try rebooting your device

                        The web server allows you to transfer ROM files from your computer to your device over your local network.
                        """
                        let alert = UIAlertController(title: "Unable to Start Web Server", message: message, preferredStyle: .alert)
                        alert.preferredContentSize = CGSize(width: 300, height: 200)
#if !os(tvOS)
                        alert.popoverPresentationController?.barButtonItem = barButtonItem
                        alert.popoverPresentationController?.sourceView = sender
                        alert.popoverPresentationController?.sourceRect = sender?.bounds ?? UIScreen.main.bounds
#endif
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
                        }))
                        self.present(alert, animated: true) { () -> Void in }
                    }
                } catch {
                    let message = """
                    Could not start the web server. Try these steps:

                    1. Make sure your device is connected to Wi-Fi
                    2. Check that ports 80 and 81 are not in use by other apps
                    3. Restart the app and try again
                    4. If the problem persists, try rebooting your device

                    The web server allows you to transfer ROM files from your computer to your device over your local network.
                    """
                    let alert = UIAlertController(title: "Unable to Start Web Server", message: message, preferredStyle: .alert)
                    alert.preferredContentSize = CGSize(width: 300, height: 200)
#if !os(tvOS)
                    alert.popoverPresentationController?.barButtonItem = barButtonItem
                    alert.popoverPresentationController?.sourceView = sender
                    alert.popoverPresentationController?.sourceRect = sender?.bounds ?? UIScreen.main.bounds
#endif
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
                    }))
                    self.present(alert, animated: true) { () -> Void in }
                }
            }
        } else {
            let message = """
            The web server requires a Wi-Fi connection to work.

            Please connect your device to a Wi-Fi network and try again. The web server allows you to transfer ROM files from your computer to your device over your local network.

            Make sure both your device and computer are on the same Wi-Fi network.
            """
            let alert = UIAlertController(title: "Wi-Fi Connection Required", message: message, preferredStyle: .alert)
            alert.preferredContentSize = CGSize(width: 300, height: 180)
            alert.popoverPresentationController?.barButtonItem = barButtonItem
#if !os(tvOS)
            alert.popoverPresentationController?.sourceView = sender
            alert.popoverPresentationController?.sourceRect = sender?.bounds ?? UIScreen.main.bounds
#endif
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) { () -> Void in }
        }
    }
}
#endif
