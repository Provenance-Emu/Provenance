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
    @State private var showingDocumentPicker = false
    @State private var importMessage: String? = nil
    @State private var showingImportMessage = false
    @State private var showingSettings = true

    var body: some View {
        NavigationView {
            let gameImporter = GameImporter.shared
            let pvgamelibraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: gameImporter)
            let menuDelegate = MockPVMenuDelegate()

            PVSettingsView(
                conflictsController: pvgamelibraryUpdatesController,
                menuDelegate: menuDelegate,
                showsDoneButton: false
            ) {
                showingSettings = false
            }
            .navigationBarHidden(true)
#if canImport(FreemiumKit)
            .environmentObject(FreemiumKit.shared)
#endif
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(onImport: importFiles)
        }
        .retroAlert("Import Result",
                    message: importMessage ?? "",
                    isPresented: $showingImportMessage) {
            Button("OK", role: .cancel) {}
        }
        .toggleStyle(.button)
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
