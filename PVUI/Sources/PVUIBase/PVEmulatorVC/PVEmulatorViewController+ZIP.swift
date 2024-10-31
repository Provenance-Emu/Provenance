//
//  PVEmulatoreViewController+ZIP.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//

import Foundation

// MARK: File loading
extension PVEmulatorViewController {
    internal func handleArchives(atPath romPathMaybe: URL?) -> URL? {
#warning("Handle the async completion handler")
        var romPathMaybe = romPathMaybe
        if core.extractArchive, let filePath = romPathMaybe {
            if (filePath.pathExtension.caseInsensitiveCompare("zip") == .orderedSame) {
                var unzippedFiles = [URL]()
                
                Task {
                    let savePath = self.batterySavesPath.standardizedFileURL
                    SSZipArchive.unzipFile(
                        atPath: filePath.path,
                        toDestination: savePath.path(percentEncoded: false),
                        overwrite: true, password: nil,
                        progressHandler: { (entry: String, _: unz_file_info, entryNumber: Int, total: Int) in
                            if !entry.isEmpty {
                                let url = savePath.appendingPathComponent(entry)
                                unzippedFiles.append(url)
                            }
                        },
                        completionHandler: { [weak self] (_: String?, succeeded: Bool, error: Error?) in
                            guard let self = self else { return }
                            if succeeded {
                                var hasCue:Bool = false;
                                var cueFile:URL?
                                for file in unzippedFiles {
                                    if self.game.system.supportedExtensions.contains( file.pathExtension.lowercased() ) {
                                        romPathMaybe = file;
                                        if (file.pathExtension.lowercased() == "cue") {
                                            cueFile = file;
                                            hasCue = true;
                                        }
                                    }
                                }
                                if hasCue, let file = cueFile {
                                    romPathMaybe = file;
                                }
                            }
                        })
                }
                
            }
        }
        return romPathMaybe
    }
}
