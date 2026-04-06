//
//  PVEmulatorViewController+ZIP.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//

import Foundation
import PVArchiving

// MARK: - Archive extraction

extension PVEmulatorViewController {

    /// Extracts a ZIP archive to the battery-saves directory and returns the
    /// best ROM file found inside (preferring `.cue` for disc-based systems).
    /// Returns the original path unchanged when the file isn't a ZIP or the
    /// core doesn't request extraction.
    internal func handleArchives(atPath romPath: URL?) async -> URL? {
        guard core.extractArchive,
              let filePath = romPath,
              filePath.pathExtension.caseInsensitiveCompare("zip") == .orderedSame else {
            return romPath
        }

        let savePath = batterySavesPath.standardizedFileURL

        do {
            var extractedFiles = [URL]()
            for try await url in ArchiveManager.shared.extract(at: filePath, to: savePath, format: .zip) {
                extractedFiles.append(url)
            }

            guard let system = game.system else { return romPath }
            let supported = system.supportedExtensions

            var bestMatch: URL?
            var cueFile: URL?
            for file in extractedFiles {
                let ext = file.pathExtension.lowercased()
                guard supported.contains(ext) else { continue }
                if bestMatch == nil { bestMatch = file }
                if ext == "cue" { cueFile = file }
            }

            return cueFile ?? bestMatch ?? romPath
        } catch {
            ELOG("Archive extraction failed: \(error.localizedDescription)")
            return romPath
        }
    }
}
