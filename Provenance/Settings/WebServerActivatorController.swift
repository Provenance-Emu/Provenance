//
//  WebServerActivatorController.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 5/29/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import UIKit

protocol WebServerActivatorController : class {
	func showServerActiveAlert()
}

#if os(iOS)
extension WebServerActivatorController where Self:PVSettingsViewController {
	// Show "Web Server Active" alert view
	func showServerActiveAlert() {
		let message = """
            Read Importing ROMs wiki…
            Upload/Download files at:


            """
		let alert = UIAlertController(title: "Web Server Active", message: message, preferredStyle: .alert)
		let ipField = UITextView(frame: CGRect(x: 20, y: 75, width: 231, height: 70))
		ipField.backgroundColor = UIColor.clear
		ipField.textAlignment = .center
		ipField.font = UIFont.systemFont(ofSize: 13)
		ipField.textColor = UIColor.gray
		let ipFieldText = """
		WebUI: \(PVWebServer.shared.urlString)
		WebDav: \(PVWebServer.shared.webDavURLString)
		"""
		ipField.text = ipFieldText
		ipField.isUserInteractionEnabled = false
		alert.view.addSubview(ipField)
		alert.addAction(UIAlertAction(title: "Stop", style: .cancel, handler: {(_ action: UIAlertAction) -> Void in
			PVWebServer.shared.stopServers()
		}))
		if #available(iOS 9.0, *) {
			let viewAction = UIAlertAction(title: "View", style: .default, handler: {(_ action: UIAlertAction) -> Void in
				self.showServer()
			})
			alert.addAction(viewAction)
		}
		present(alert, animated: true) {() -> Void in }
	}
}
#endif

#if os(tvOS)
typealias WebServerActivatorControllerRootClass = UIViewController
#else
typealias WebServerActivatorControllerRootClass = PVGameLibraryViewController
#endif

extension WebServerActivatorController where Self: WebServerActivatorControllerRootClass {
	var webServerAlertMessage : String {
		// get the IP address or bonjour name of the device
		let webServerAddress: String = PVWebServer.shared.urlString
		let webDavAddress: String = PVWebServer.shared.webDavURLString
		let message = """
		Read Importing ROMs wiki…
		Upload/Download files at:

		\(webServerAddress)  ᵂᵉᵇᵁᴵ
		\(webDavAddress)  ᵂᵉᵇᴰᵃᵛ

		"""
		return  message
	}

	func showServerActiveAlert() {
		// Start Webserver
		// Check to see if we are connected to WiFi. Cannot continue otherwise.
		let reachability = Reachability.forLocalWiFi()
		reachability.startNotifier()
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

				let alert = UIAlertController(title: "Web Server Active", message: webServerAlertMessage, preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "Stop", style: .default, handler: {(_ action: UIAlertAction) -> Void in
					PVWebServer.shared.stopServers()
				}))
				#if os(iOS)
				if #available(iOS 9.0, *) {
					let viewAction = UIAlertAction(title: "View", style: .default, handler: {(_ action: UIAlertAction) -> Void in
						self.showServer()
					})
					alert.addAction(viewAction)
				}
				#endif
				present(alert, animated: true) {() -> Void in
					alert.message = self.webServerAlertMessage
				}
			} else {
				// Display error
                let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or settings and free up ports: 80, 81", preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
				}))
				present(alert, animated: true) {() -> Void in }
			}
		}
	}
}
