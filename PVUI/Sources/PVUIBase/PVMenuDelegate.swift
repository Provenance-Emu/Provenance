//
//  PVMenuDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/23/24.
//

import UIKit
import SwiftUI
#if canImport(PVWebServer)
import PVWebServer
#endif

public protocol PVMenuDelegate: AnyObject {
    func didTapImports()
    func didTapSettings()
    func didTapHome()
    func didTapAddGames()
    func didTapConsole(with consoleId: String)
    func didTapCollection(with collection: Int)
    func closeMenu()
}

#if canImport(PVWebServer)
extension PVMenuDelegate where Self: WebServerActivatorController & WebServerActivatorControllerRootClass {
    
    public func showServer() {
        guard let ipURL: String = PVWebServer.shared.urlString else {
            ELOG("`PVWebServer.shared.urlString` was nil")
            return
        }
        let url = URL(string: ipURL)!
#if targetEnvironment(macCatalyst)
        UIApplication.shared.open(url, options: [:]) { completed in
            ILOG("Completed: \(completed ? "Yes":"No")")
        }
#elseif canImport(SafariServices)
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.delegate = self
        present(safariVC, animated: true) { () -> Void in }
#endif
    }
    
    public func showServerActiveAlert(sender: UIView?, barButtonItem: UIBarButtonItem?) {
        let alert = UIAlertController(title: "Web Server Active", message: webServerAlertMessage, preferredStyle: .alert)
        alert.popoverPresentationController?.barButtonItem = barButtonItem
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender?.bounds ?? UIScreen.main.bounds
        alert.preferredContentSize = CGSize(width: 300, height: 150)
        alert.addAction(UIAlertAction(title: "Stop", style: .cancel, handler: { (_: UIAlertAction) -> Void in
            PVWebServer.shared.stopServers()
        }))
        let viewAction = UIAlertAction(title: "View", style: .default, handler: { (_: UIAlertAction) -> Void in
            self.showServer()
        })
        alert.addAction(viewAction)
        alert.preferredAction = alert.actions.last
        present(alert, animated: true) { () -> Void in }
    }
    
    
    public func startWebServer() {
        // start web transfer service
        if PVWebServer.shared.startServers() {
            // show alert view
            showServerActiveAlert(sender: self.view, barButtonItem: navigationItem.rightBarButtonItem)
        } else {
#if targetEnvironment(simulator) || targetEnvironment(macCatalyst) || os(macOS)
            let message = "Check your network connection or settings and free up ports: 8080, 8081."
#else
            let message = "Check your network connection or settings and free up ports: 80, 81."
#endif
            let alert = UIAlertController(title: "Unable to start web server!", message: message, preferredStyle: .alert)
            alert.preferredContentSize = CGSize(width: 300, height: 150)
            alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = self.view?.bounds ?? UIScreen.main.bounds
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) { () -> Void in }
        }
    }

}
#endif
