//
//  SettingsView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVThemes
import PVUIBase
import PVLibrary
import UniformTypeIdentifiers
import PVLogging
#if canImport(FreemiumKit)
import FreemiumKit
#endif

struct SettingsWrapperView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    #if os(tvOS)
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @Binding var canPop: Bool
    #endif
    #if !os(tvOS)
    @State private var showingDocumentPicker = false
    #endif
    @State private var importMessage: String? = nil
    @State private var showingImportMessage = false
    @State private var showingSettings = true

    /// Stable across re-renders — must NOT be created inside `body` or SwiftUI
    /// will re-instantiate it on every render cycle, causing an init→observer→
    /// state-change→re-render infinite loop.
    @StateObject private var conflictsController = PVGameLibraryUpdatesController(
        gameImporter: GameImporter.shared
    )
    private let menuDelegate = MockPVMenuDelegate()

    #if os(tvOS)
    init(canPop: Binding<Bool> = .constant(false)) {
        _canPop = canPop
    }
    #else
    init() {}
    #endif

    var body: some View {
        // PVSettingsView already contains its own NavigationStack.
        // Do NOT wrap it in another NavigationStack here — nested stacks
        // prevent NavigationLink activation on tvOS.
        settingsView
#if canImport(FreemiumKit)
        .environmentObject(FreemiumKit.shared)
#endif
        #if !os(tvOS)
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(onImport: importFiles)
        }
        #endif
        .retroAlert("Import Result",
                    message: importMessage ?? "",
                    isPresented: $showingImportMessage) {
            Button("OK", role: .cancel) {}
        }
        #if os(tvOS)
        .toggleStyle(.automatic)
        #else
        .toggleStyle(.button)
        #endif
    }

    @ViewBuilder
    private var settingsView: some View {
        #if os(tvOS)
        PVSettingsView(
            conflictsController: conflictsController,
            menuDelegate: menuDelegate,
            showsDoneButton: false,
            onSubpagePushChanged: { pushed in canPop = pushed }
        ) {
            showingSettings = false
        }
        .navigationBarHidden(true)
        .background(TVOSSettingsNavigationCanPopReader(canPop: $canPop))
        #else
        PVSettingsView(
            conflictsController: conflictsController,
            menuDelegate: menuDelegate,
            showsDoneButton: false
        ) {
            showingSettings = false
        }
        .navigationBarHidden(true)
        #endif
    }

    private func importFiles(urls: [URL]) {
        ILOG("SettingsView: Importing \(urls.count) files")

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            ELOG("SettingsView: Could not access documents directory")
            importMessage = "Error: Could not access documents directory"
            showingImportMessage = true
            return
        }

        let importsDirectory = documentsDirectory.appendingPathComponent("Imports", isDirectory: true)

        // Create Imports directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: importsDirectory, withIntermediateDirectories: true)
        } catch {
            ELOG("SettingsView: Error creating Imports directory: \(error.localizedDescription)")
            importMessage = "Error creating Imports directory: \(error.localizedDescription)"
            showingImportMessage = true
            return
        }

        var successCount = 0
        var errorMessages = [String]()

        for url in urls {
            let destinationURL = importsDirectory.appendingPathComponent(url.lastPathComponent)

            do {
                // If file already exists, remove it first
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                // Copy file to Imports directory
                try FileManager.default.copyItem(at: url, to: destinationURL)
                ILOG("SettingsView: Successfully copied \(url.lastPathComponent) to Imports directory")
                successCount += 1
            } catch {
                ELOG("SettingsView: Error copying file \(url.lastPathComponent): \(error.localizedDescription)")
                errorMessages.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Prepare result message
        if successCount == urls.count {
            importMessage = "Successfully imported \(successCount) file(s). The game importer will process them shortly."
        } else if successCount > 0 {
            importMessage = "Imported \(successCount) of \(urls.count) file(s). Some files could not be imported."
        } else {
            importMessage = "Failed to import any files. \(errorMessages.first ?? "Unknown error")"
        }

        showingImportMessage = true
    }
}

extension Notification.Name {
    /// Posted by tvOS media shell when Settings should pop one navigation level.
    static let tvOSSettingsRequestPop = Notification.Name("TVOSSettingsRequestPop")
}

/// Tracks whether the Settings navigation stack can pop (i.e. a subpage is pushed).
/// This is used by the tvOS Media UI to suppress sidebar gestures while inside Settings subpages.
private struct TVOSSettingsNavigationCanPopReader: UIViewControllerRepresentable {
    @Binding var canPop: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller(canPop: $canPop)
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.canPop = $canPop
        uiViewController.refresh()
    }

    final class Controller: UIViewController, UINavigationControllerDelegate {
        var canPop: Binding<Bool>

        init(canPop: Binding<Bool>) {
            self.canPop = canPop
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        deinit {
            NotificationCenter.default.removeObserver(self, name: .tvOSSettingsRequestPop, object: nil)
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleSettingsPopRequest),
                                                   name: .tvOSSettingsRequestPop,
                                                   object: nil)
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            refresh()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            refresh()
        }

        func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
            refresh(for: navigationController)
        }

        func refresh() {
            // SwiftUI can host nested NavigationStack containers, where `self.navigationController`
            // may be nil even though a stack is active. Resolve the closest active UINavigationController.
            refresh(for: resolvedNavigationController())
        }

        private func refresh(for navigationController: UINavigationController?) {
            navigationController?.delegate = self
            let value = (navigationController?.viewControllers.count ?? 1) > 1
            if canPop.wrappedValue != value {
                canPop.wrappedValue = value
            }
        }

        /// Resolves the nearest active UINavigationController for this representable.
        /// This keeps `canPop` accurate when Settings is hosted inside nested SwiftUI stacks.
        private func resolvedNavigationController() -> UINavigationController? {
            if let navigationController {
                return navigationController
            }

            var ancestor = parent
            while let current = ancestor {
                if let nav = current as? UINavigationController {
                    return nav
                }
                if let nav = firstNavigationController(in: current.children) {
                    return nav
                }
                ancestor = current.parent
            }

            return firstNavigationController(in: children)
        }

        /// Depth-first search for the first UINavigationController within child controllers.
        private func firstNavigationController(in controllers: [UIViewController]) -> UINavigationController? {
            for controller in controllers {
                if let nav = controller as? UINavigationController {
                    return nav
                }
                if let nav = firstNavigationController(in: controller.children) {
                    return nav
                }
            }
            return nil
        }

        /// Pops one Settings subpage when requested by the parent tvOS shell.
        @objc private func handleSettingsPopRequest() {
            guard let nav = resolvedNavigationController(), nav.viewControllers.count > 1 else { return }
            nav.popViewController(animated: true)
            refresh(for: nav)
        }
    }
}
