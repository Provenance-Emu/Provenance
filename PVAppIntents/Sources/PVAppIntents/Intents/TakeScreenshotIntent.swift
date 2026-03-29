//
//  TakeScreenshotIntent.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Captures a screenshot of the currently running game.
///
/// The host app handles `pendingTakeScreenshot` in
/// `PVAppDelegate.processPendingIntents()`, saves the image to the Photos
/// library and the Provenance screenshots directory, then writes the resulting
/// file URL back to `lastScreenshotURL` in the App Group UserDefaults so that
/// Shortcuts can pass the image downstream.
///
/// Usage: "Hey Siri, take a screenshot on Provenance"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct TakeScreenshotIntent: AppIntent {
    public static let title: LocalizedStringResource = "Take Screenshot"
    public static let description = IntentDescription(
        "Captures a screenshot of the current game in Provenance.",
        categoryName: "Emulation"
    )

    public static let openAppWhenRun: Bool = false

    // MARK: - Init

    public init() {}

    // MARK: - Perform

    /// Returns an `IntentFile` wrapping the screenshot so Shortcuts can pipe
    /// the image into subsequent actions (e.g. share sheet, save to Files).
    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<IntentFile?> {
        guard pvGameIsActive else {
            throw AppIntentError.noActiveSession
        }
        // Clear any stale screenshot URL *before* signalling the host app to avoid
        // a race where the app writes a new URL before we reach the polling loop.
        pvAppGroupDefaults?.removeObject(forKey: "lastScreenshotURL")
        // Signal the host app to capture a screenshot.
        pvAppGroupDefaults?.set(true, forKey: "pendingTakeScreenshot")

        // Poll for up to 3 s for the host app to write back the screenshot URL.
        let screenshotFile = try await waitForScreenshotFile(timeout: 3.0)

        let dialog: LocalizedStringResource = screenshotFile != nil
            ? "Screenshot saved."
            : "Screenshot requested — check your Photos library."

        return .result(value: screenshotFile, dialog: dialog)
    }

    // MARK: - Private helpers

    /// Polls `lastScreenshotURL` in App Group UserDefaults until the host app
    /// writes a value or the timeout elapses. Clears the key after consuming the URL.
    private func waitForScreenshotFile(timeout: TimeInterval) async throws -> IntentFile? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 s
            if let urlString = pvAppGroupDefaults?.string(forKey: "lastScreenshotURL"),
               let url = URL(string: urlString) {
                pvAppGroupDefaults?.removeObject(forKey: "lastScreenshotURL")
                let data = (try? Data(contentsOf: url)) ?? Data()
                return IntentFile(data: data, filename: url.lastPathComponent, type: .png)
            }
        }
        return nil
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Take a screenshot in \(.applicationName)")
    }
}
#endif
