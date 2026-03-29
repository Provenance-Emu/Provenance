//
//  PVEmulatoreViewController+ZIP.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//

import Foundation
import PVArchiving

// MARK: File loading
extension PVEmulatorViewController {
    internal func handleArchives(atPath romPathMaybe: URL?) -> URL? {
#warning("Handle the async completion handler")
        var romPathMaybe = romPathMaybe
        if core.extractArchive, let filePath = romPathMaybe {
            if (filePath.pathExtension.caseInsensitiveCompare("zip") == .orderedSame) {
                var unzippedFiles = [URL]()

                Task.detached {
                    let savePath = self.batterySavesPath.standardizedFileURL
                    do {
                        for try await url in ArchiveManager.shared.extract(at: filePath, to: savePath, format: .zip) {
                            unzippedFiles.append(url)
                        }
                        await MainActor.run { [weak self] in
                            guard let self else { return }
                            var hasCue = false
                            var cueFile: URL?
                            for file in unzippedFiles {
                                if let system = self.game.system,
                                   system.supportedExtensions.contains(file.pathExtension.lowercased()) {
                                    romPathMaybe = file
                                    if file.pathExtension.lowercased() == "cue" {
                                        cueFile = file
                                        hasCue = true
                                    }
                                }
                            }
                            if hasCue, let file = cueFile {
                                romPathMaybe = file
                            }
                        }
                    } catch {
                        ELOG("Archive extraction failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        return romPathMaybe
    }
}
