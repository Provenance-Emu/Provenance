//
//  EmuSkinsApp.swift
//  EmuSkins
//
//  Created by Joseph Mattiello on 2/26/25.
//

import SwiftUI
import PVUIBase
import PVLogging
import UniformTypeIdentifiers

@main
struct EmuSkinsApp: App {
    /// Shared DeltaSkinManager instance
    @StateObject private var skinManager = DeltaSkinManager.shared

    /// State to track any import errors
    @State private var importError: Error?
    @State private var showingImportError = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(skinManager)
                // Handle URLs opened with our custom scheme
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                // Handle files opened from Finder/Files app
                .onDrop(of: [UTType.deltaSkin], isTargeted: nil) { providers in
                    Task {
                        await handleDroppedItems(providers)
                    }
                    return true
                }
                .alert("Import Error", isPresented: $showingImportError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(importError?.localizedDescription ?? "Failed to import skin")
                }
        }
    }

    /// Handle URLs opened with our custom scheme or universal links
    private func handleIncomingURL(_ url: URL) {
        Task {
            do {
                // Create a temporary URL for the copy
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("deltaskin")

                // Start accessing the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    ELOG("Failed to start accessing security-scoped resource")
                    throw DeltaSkinError.accessDenied
                }

                defer {
                    url.stopAccessingSecurityScopedResource()
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: tempURL)
                }

                // Copy the file to temporary storage
                try FileManager.default.copyItem(at: url, to: tempURL)

                // Import the skin from the temporary location
                try await skinManager.importSkin(from: tempURL)
                await skinManager.reloadSkins()
            } catch {
                ELOG("Failed to import skin from URL: \(error)")
                importError = error
                showingImportError = true
            }
        }
    }

    /// Handle files dropped onto the app
    private func handleDroppedItems(_ providers: [NSItemProvider]) async {
        for provider in providers {
            do {
                // Load the dropped file URL
                guard let url = try await provider.loadItem(forTypeIdentifier: UTType.deltaSkin.identifier) as? URL else {
                    continue
                }

                // Create a temporary URL for the copy
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("deltaskin")

                // Start accessing the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    ELOG("Failed to start accessing security-scoped resource")
                    throw DeltaSkinError.accessDenied
                }

                defer {
                    url.stopAccessingSecurityScopedResource()
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: tempURL)
                }

                // Copy the file to temporary storage
                try FileManager.default.copyItem(at: url, to: tempURL)

                // Import the skin from the temporary location
                try await skinManager.importSkin(from: tempURL)
                await skinManager.reloadSkins()
            } catch {
                ELOG("Failed to import dropped skin: \(error)")
                importError = error
                showingImportError = true
            }
        }
    }
}
