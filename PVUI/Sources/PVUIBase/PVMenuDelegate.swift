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
#if canImport(SafariServices)
import SafariServices
#endif

public protocol PVMenuDelegate: AnyObject {
    func didTapImports()
    func didTapSettings()
    func didTapHome()
    func didTapAddGames()
    func didTapConsole(with consoleId: String)
    func didTapCollection(with collection: Int)
    func closeMenu()

    // MARK: - Library Management Actions

    /// Scan ROM directories for new and updated files. Does not modify existing metadata.
    func didTapScanROMs()

    /// Re-fetch metadata and artwork from the database. Preserves custom artwork and names.
    func didTapUpdateMetadata()

    /// Delete all cached artwork to free space. Images are re-downloaded on demand.
    func didTapClearArtworkCache()

    /// Delete all game data, settings and configurations, then re-import everything.
    /// This is destructive and removes custom artwork and names.
    func didTapResetLibrary()
}

// MARK: - Default Library Management Implementations

/// Default implementations post the existing NSNotification names so all existing
/// observers (PVAppDelegate) continue to work without any changes.
public extension PVMenuDelegate {

    func didTapScanROMs() {
        NotificationCenter.default.post(name: .PVReimportLibrary, object: nil)
    }

    func didTapUpdateMetadata() {
        NotificationCenter.default.post(name: .PVRefreshLibrary, object: nil)
    }

    func didTapClearArtworkCache() {
        // No notification needed — callers invoke PVMediaCache.empty() directly.
    }

    func didTapResetLibrary() {
        NotificationCenter.default.post(name: .PVResetLibrary, object: nil)
    }
}

#if canImport(PVWebServer)

#if os(tvOS)
public typealias WebServerDelegateViewController = WebServerActivatorController & WebServerActivatorControllerRootClass
#else
public typealias WebServerDelegateViewController = WebServerActivatorController & SFSafariViewControllerDelegate & UIViewController
#endif

extension PVMenuDelegate where Self: WebServerDelegateViewController {
    
    public func showServer() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let ipURL = await PVWebServerManager.shared.serverURL?.absoluteString else {
                ELOG("`PVWebServerManager.shared.serverURL` was nil")
                return
            }
            let url = URL(string: ipURL)!
#if targetEnvironment(macCatalyst)
            UIApplication.shared.open(url, options: [:]) { completed in
                ILOG("Completed: \(completed ? "Yes":"No")")
            }
#elseif canImport(SafariServices) && !os(tvOS)
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = false
            let safariVC = SFSafariViewController(url: url, configuration: config)
            safariVC.delegate = self
            self.present(safariVC, animated: true) { () -> Void in }
#endif
        }
    }
    
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
                            self?.didTapImports()
                        }
                    }
                }
            }))
            let viewAction = UIAlertAction(title: "View", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.showServer()
            })
            alert.addAction(viewAction)
            alert.preferredAction = alert.actions.last
            self.present(alert, animated: true) { () -> Void in }
        }
    }
}
#endif
