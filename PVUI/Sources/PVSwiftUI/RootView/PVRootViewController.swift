//
//  PVRootViewController.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
#if canImport(Combine)
#if canImport(UIKit)
import UIKit
#endif
import RxSwift
import PVUIBase
import SwiftUI
import RealmSwift
import Combine
import PVLibrary
import PVRealm
import PVLogging

@_exported import PVUIBase

#if canImport(MBProgressHUD)
import MBProgressHUD
#endif

// PVRootViewController serves as a UIKit parent for child SwiftUI menu views.

// The goal one day may be to move entirely to a SwiftUI app life cycle, but under
// current circumstances (iOS 11 deployment target, some critical logic being coupled
// to UIViewControllers, etc.) it will be more easier to integrate by starting here
// and porting the remaining views/logic over to as conditions change moving forward.

public enum PVNavOption {
    case settings
    case home
    case console(consoleId: String, title: String)
    
    var title: String {
        switch self {
        case .settings: return "Settings"
        case .home: return "Home"
        case .console(_, let title):  return title
        }
    }
}

@available(iOS 14, tvOS 14, *)
public class PVRootViewController: UIViewController, GameLaunchingViewController, GameSharingViewController {
    
    let containerView = UIView()
    var viewModel: PVRootViewModel!
    
    var updatesController: PVGameLibraryUpdatesController!
    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>!
    var gameImporter: GameImporter!
    
    var selectedTabCancellable: AnyCancellable?
    
    lazy var consolesWrapperViewDelegate = ConsolesWrapperViewDelegate()
    var consoleIdentifiersAndNamesMap: [String:String] = [:]
    
    public static func instantiate(updatesController: PVGameLibraryUpdatesController, gameLibrary: PVGameLibrary<RealmDatabaseDriver>, gameImporter: GameImporter, viewModel: PVRootViewModel) -> PVRootViewController {
        let controller = PVRootViewController()
        controller.updatesController = updatesController
        controller.gameLibrary = gameLibrary
        controller.gameImporter = gameImporter
        controller.viewModel = viewModel
        return controller
    }
    
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(containerView)
        self.fillParentView(child: containerView, parent: self.view)
        
        self.determineInitialView()
        
        let hud = MBProgressHUD(view: view)
        hud.isUserInteractionEnabled = false
        view.addSubview(hud)
        
        setupHUDObserver(hud: hud)
    }
    
    private var cancellables = Set<AnyCancellable>()
    private func setupHUDObserver(hud: MBProgressHUD) {
        Task { @MainActor in
            for try await state in updatesController.$hudState.values {
                updateHUD(hud: hud, state: state)
            }
        }
    }
    private func updateHUD(hud: MBProgressHUD, state: PVGameLibraryUpdatesController.HudState) {
        switch state {
        case .hidden:
            hud.hide(animated: true)
        case .title(let title):
            hud.show(animated: true)
            hud.mode = .indeterminate
            hud.label.text = title
            hud.label.numberOfLines = 2
        case .titleAndProgress(let title, let progress):
            hud.show(animated: true)
            hud.mode = .annularDeterminate
            hud.progress = progress
            hud.label.text = title
            hud.label.numberOfLines = 2
        }
    }
    
    deinit {
        selectedTabCancellable?.cancel()
    }
    
    func showMenu() {
        self.sideNavigationController?.showLeftSide()
    }
    
    func closeMenu() {
        self.sideNavigationController?.closeSide()
    }
    
    func determineInitialView() {
        if let console = gameLibrary.activeSystems.first {
            didTapConsole(with: console.identifier)
        } else {
            didTapHome()
        }
    }
    
    func loadIntoContainer(_ navItem: PVNavOption, newVC: UIViewController) {
        // remove old view
        self.containerView.subviews.forEach { $0.removeFromSuperview() }
        self.children.forEach { $0.removeFromParent() }
        // set title
        self.navigationItem.title = navItem.title
        // set bar button items (if any)
        switch navItem {
        case .settings, .home, .console:
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"), primaryAction: UIAction { _ in
                self.showMenu()
            })
        }
        // load new view
        self.addChildViewController(newVC, toContainerView: self.containerView)
        self.fillParentView(child: newVC.view, parent: self.containerView)
    }
}

// MARK: - Helpers
extension UIViewController {
    
    func addChildViewController(_ child: UIViewController, toContainerView containerView: UIView) {
        addChild(child)
        containerView.addSubview(child.view)
        child.didMove(toParent: self)
    }
    
    func fillParentView(child: UIView, parent: UIView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        ])
    }
    
}

#if os(iOS) || targetEnvironment(macCatalyst)
// MARK: - UIDocumentPickerDelegate
extension PVRootViewController: UIDocumentPickerDelegate {
    // copied from PVGameLibraryViewController#documentPicker()
    public func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // If directory, map out sub directories if folder
        let urls: [URL] = urls.compactMap { (url) -> [URL]? in
            if url.hasDirectoryPath {
                ILOG("Trying to import directory \(url.path). Scanning subcontents")
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        ELOG("startAccessingSecurityScopedResource failed")
                        return nil
                    }
                    
                    defer {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    let subFiles = try FileManager.default.contentsOfDirectory(at: url,
                                                                               includingPropertiesForKeys: [URLResourceKey.isDirectoryKey, URLResourceKey.parentDirectoryURLKey, URLResourceKey.fileSecurityKey],
                                                                               options: .skipsHiddenFiles)
                    return subFiles
                } catch {
                    ELOG("Subdir scan failed. \(error)")
                    return [url]
                }
            } else {
                return [url]
            }
        }.joined().map { $0 }
        
        let sortedUrls = PVEmulatorConfiguration.sortImportURLs(urls: urls)
        
        let importPath = Paths.romsImportPath
        
        var securityScoped = false
        
        sortedUrls.forEach { url in
            defer {
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Doesn't seem we need access in dev builds?
            // if this returns false, we don't need to balance with a stop call, so just hang on to the value
            securityScoped = url.startAccessingSecurityScopedResource()
            
            let fileName = url.lastPathComponent
            let destination: URL
            destination = importPath.appendingPathComponent(fileName, isDirectory: url.hasDirectoryPath)
            do {
                // Since we're in UIDocumentPickerModeImport, these URLs are temporary URLs so a move is what we want
                try FileManager.default.moveItem(at: url, to: destination)
                ILOG("Document picker to moved file from \(url.path) to \(destination.path)")
            } catch {
                ELOG("hsllo::\(error)")
                ELOG("Failed to move file from \(url.path) to \(destination.path)")
            }
        }
        
        // Test for moving directory subcontents
        //                    if #available(iOS 9.0, *) {
        //                        if url.hasDirectoryPath {
        //                            ILOG("Tryingn to import directory \(url.path)")
        //                            let subFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        //                            for subFile in subFiles {
        //                                _ = subFile.startAccessingSecurityScopedResource()
        //                                try FileManager.default.moveItem(at: subFile, to: destination)
        //                                subFile.stopAccessingSecurityScopedResource()
        //                                ILOG("Moved \(subFile.path) to \(destination.path)")
        //                            }
        //                        } else {
        //                            try FileManager.default.moveItem(at: url, to: destination)
        //                        }
        //                    } else {
        //                        try FileManager.default.moveItem(at: url, to: destination)
        //                    }
        //                } catch {
        //                    ELOG("Failed to move file from \(url.path) to \(destination.path)")
        //                }
        //            } else {
        //                ELOG("Wasn't granded access to \(url.path)")
        //            }
    }
    
    public func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        ILOG("Document picker was cancelled")
    }
}
#endif // os(iOS)
#endif // canImport(Combine)
#endif // canImport(SwiftUI)
