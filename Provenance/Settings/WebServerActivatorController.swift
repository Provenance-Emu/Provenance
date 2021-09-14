//
//  WebServerActivatorController.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 5/29/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import PVLibrary
import PVSupport
import Reachability
import UIKit

protocol WebServerActivatorController: AnyObject {
    func showServerActiveAlert()
}

#if os(iOS)
    import SafariServices

    extension WebServerActivatorController where Self: UIViewController & SFSafariViewControllerDelegate {
        // Show "Web Server Active" alert view
        var webServerAlertMessage: String {
            let webServerAddress: String = PVWebServer.shared.urlString
            let webDavAddress: String = PVWebServer.shared.webDavURLString
            let message = """
            Read about how to import ROMs on the Provenance wiki at:
            https://wiki.provenance-emu.com

            Upload/Download files to your device at:

            \(webServerAddress)  ᵂᵉᵇᵁᴵ
            \(webDavAddress)  ᵂᵉᵇᴰᵃᵛ
            """
            return message
        }

        func showServerActiveAlert() {
            let alert = UIAlertController(title: "Web Server Active", message: webServerAlertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Stop", style: .cancel, handler: { (_: UIAlertAction) -> Void in
                PVWebServer.shared.stopServers()
            }))
            let viewAction = UIAlertAction(title: "View", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.showServer()
            })
            alert.addAction(viewAction)
            present(alert, animated: true) { () -> Void in }
        }

        func showServer() {
            let ipURL: String = PVWebServer.shared.urlString
            let url = URL(string: ipURL)!
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = false
            let safariVC = SFSafariViewController(url: url, configuration: config)
            safariVC.delegate = self
            present(safariVC, animated: true) { () -> Void in }
        }
    }
#endif

#if os(tvOS)
    typealias WebServerActivatorControllerRootClass = UIViewController
#else
    typealias WebServerActivatorControllerRootClass = PVGameLibraryViewController
#endif

extension WebServerActivatorController where Self: WebServerActivatorControllerRootClass {
    var webServerAlertMessage: String {
        // get the IP address or bonjour name of the device
        let webServerAddress: String = PVWebServer.shared.urlString
        let webDavAddress: String = PVWebServer.shared.webDavURLString
        let message = """
        Read about how to import ROMs on the Provenance wiki at:
        https://wiki.provenance-emu.com

        Upload/Download files to your device at:

        \(webServerAddress)  ᵂᵉᵇᵁᴵ
        \(webDavAddress)  ᵂᵉᵇᴰᴬⱽ
        """
        return message
    }

    func showServerActiveAlert() {
        // Start Webserver
        // Check to see if we are connected to WiFi. Cannot continue otherwise.
        let reachability = try! Reachability()

        do {
            try reachability.startNotifier()
        } catch {
            ELOG("Failed to start reachability: \(error.localizedDescription)")
        }

        if reachability.connection == .wifi {
            // connected via wifi, let's continue
            // start web transfer service
            if PVWebServer.shared.startServers() {
                let alert = UIAlertController(title: "Web Server Active", message: webServerAlertMessage, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Stop", style: .default, handler: { (_: UIAlertAction) -> Void in
                    PVWebServer.shared.stopServers()
                }))
                #if os(iOS)
                    let viewAction = UIAlertAction(title: "View", style: .default, handler: { (_: UIAlertAction) -> Void in
                        self.showServer()
                    })
                    alert.addAction(viewAction)
                #endif
                present(alert, animated: true) { () -> Void in
                    alert.message = self.webServerAlertMessage
                }
            } else {
                // Display error
                let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or settings and free up ports: 80, 81.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
                }))
                present(alert, animated: true) { () -> Void in }
            }
        } else {
            let alert = UIAlertController(title: "Unable to start web server!", message: "Your device needs to be connected to a WiFi network to continue!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) { () -> Void in }
        }
    }
}
