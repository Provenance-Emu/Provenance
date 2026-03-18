import Foundation
import ZIPFoundation
import PVLogging

// MARK: - Errors

enum DeltaSkinExportError: LocalizedError {
    case invalidJSON
    case noItemsFound(device: String, displayType: String, orientation: String)
    case archiveCreationFailed
    case unzipFailed

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Failed to serialize modified skin JSON."
        case .noItemsFound(let d, let dt, let o):
            return "No button items found for \(d)/\(dt)/\(o). The skin may not support this configuration."
        case .archiveCreationFailed:
            return "Failed to create the .deltaskin archive."
        case .unzipFailed:
            return "Failed to extract the original skin archive."
        }
    }
}

// MARK: - Exporter

/// Exports a modified copy of a DeltaSkin with updated button frame positions.
///
/// The original skin file is never modified. A new `-edited.deltaskin` file is
/// written to the temporary directory and returned for sharing.
struct DeltaSkinExporter {

    /// Create a new .deltaskin file with `modifiedFrames` applied.
    ///
    /// - Parameters:
    ///   - skin: Source skin (only `fileURL` and `jsonRepresentation` are used).
    ///   - traits: Selects which representation's items to patch.
    ///   - modifiedFrames: Button index → new CGRect in mappingSize-unit coordinates.
    /// - Returns: URL of the new .deltaskin in the temp directory.
    static func export(
        skin: any DeltaSkinProtocol,
        traits: DeltaSkinTraits,
        modifiedFrames: [Int: CGRect]
    ) async throws -> URL {
        // Build patched JSON
        var jsonDict = skin.jsonRepresentation
        try patchItems(&jsonDict, traits: traits, modifiedFrames: modifiedFrames)

        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: jsonDict,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            throw DeltaSkinExportError.invalidJSON
        }

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let baseName = skin.fileURL.deletingPathExtension().lastPathComponent
        let uniqueID = UUID().uuidString.prefix(8)
        let outputURL = tempDir.appendingPathComponent("\(baseName)-edited-\(uniqueID).deltaskin")

        let isDirectory = (try? skin.fileURL.resourceValues(
            forKeys: [.isDirectoryKey])
        )?.isDirectory ?? false

        if isDirectory {
            try exportFromDirectory(
                sourceDir: skin.fileURL,
                jsonData: jsonData,
                outputURL: outputURL,
                fm: fm
            )
        } else {
            try exportFromArchive(
                archiveURL: skin.fileURL,
                jsonData: jsonData,
                outputURL: outputURL,
                fm: fm
            )
        }

        ILOG("DeltaSkinExporter: exported to \(outputURL.lastPathComponent)")
        return outputURL
    }

    // MARK: - Private helpers

    /// Patch the `items` array inside `json` for the given traits.
    private static func patchItems(
        _ json: inout [String: Any],
        traits: DeltaSkinTraits,
        modifiedFrames: [Int: CGRect]
    ) throws {
        guard var representations = json["representations"] as? [String: Any] else {
            throw DeltaSkinExportError.noItemsFound(
                device: traits.device.rawValue,
                displayType: traits.displayType.rawValue,
                orientation: traits.orientation.rawValue
            )
        }

        // Navigate into the right slot, trying edgeToEdge ↔ standard fallback
        // (mirrors the fallback logic in DeltaSkin.resolveOrientationReps).
        let displayKeys = displayTypeKeys(for: traits)

        for deviceKey in deviceKeys(for: traits) {
            guard var deviceReps = representations[deviceKey] as? [String: Any] else { continue }
            for displayKey in displayKeys {
                guard var displayReps = deviceReps[displayKey] as? [String: Any] else { continue }
                guard var orientationRep = displayReps[traits.orientation.rawValue] as? [String: Any] else { continue }
                guard var items = orientationRep["items"] as? [[String: Any]] else {
                    throw DeltaSkinExportError.noItemsFound(
                        device: deviceKey,
                        displayType: displayKey,
                        orientation: traits.orientation.rawValue
                    )
                }

                // Apply frame overrides
                for (index, newFrame) in modifiedFrames {
                    guard index < items.count else { continue }
                    items[index]["frame"] = [
                        "x": newFrame.minX,
                        "y": newFrame.minY,
                        "width": newFrame.width,
                        "height": newFrame.height
                    ]
                }

                // Write back up the chain
                orientationRep["items"] = items
                displayReps[traits.orientation.rawValue] = orientationRep
                deviceReps[displayKey] = displayReps
                representations[deviceKey] = deviceReps
                json["representations"] = representations
                return  // success
            }
        }

        throw DeltaSkinExportError.noItemsFound(
            device: traits.device.rawValue,
            displayType: traits.displayType.rawValue,
            orientation: traits.orientation.rawValue
        )
    }

    /// Candidate device keys to try, primary first.
    private static func deviceKeys(for traits: DeltaSkinTraits) -> [String] {
        [traits.device.rawValue]
    }

    /// Candidate display-type keys to try, with edgeToEdge ↔ standard fallback.
    private static func displayTypeKeys(for traits: DeltaSkinTraits) -> [String] {
        switch traits.displayType {
        case .edgeToEdge:
            return [traits.displayType.rawValue, DeltaSkinDisplayType.standard.rawValue]
        case .standard:
            return [traits.displayType.rawValue, DeltaSkinDisplayType.edgeToEdge.rawValue]
        default:
            return [traits.displayType.rawValue]
        }
    }

    /// Export a directory-based skin (unzipped .deltaskin folder).
    private static func exportFromDirectory(
        sourceDir: URL,
        jsonData: Data,
        outputURL: URL,
        fm: FileManager
    ) throws {
        let tempSkinDir = fm.temporaryDirectory
            .appendingPathComponent("DeltaSkinEditorTemp-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempSkinDir) }

        try fm.copyItem(at: sourceDir, to: tempSkinDir)
        let infoURL = tempSkinDir.appendingPathComponent("info.json")
        try jsonData.write(to: infoURL)

        // shouldKeepParent: false so info.json is at the archive root (not under the temp folder name)
        try fm.zipItem(at: tempSkinDir, to: outputURL, shouldKeepParent: false)
    }

    /// Export a zip-archive-based .deltaskin file.
    private static func exportFromArchive(
        archiveURL: URL,
        jsonData: Data,
        outputURL: URL,
        fm: FileManager
    ) throws {
        let tempExtractDir = fm.temporaryDirectory
            .appendingPathComponent("DeltaSkinEditorExtract-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempExtractDir) }

        // Unzip original skin
        do {
            try fm.unzipItem(at: archiveURL, to: tempExtractDir)
        } catch {
            ELOG("DeltaSkinExporter: failed to unzip \(archiveURL.lastPathComponent): \(error)")
            throw DeltaSkinExportError.unzipFailed
        }

        // Overwrite info.json with patched version
        let infoURL = tempExtractDir.appendingPathComponent("info.json")
        try jsonData.write(to: infoURL)

        // Rezip — shouldKeepParent: false so info.json is at the archive root
        do {
            try fm.zipItem(at: tempExtractDir, to: outputURL, shouldKeepParent: false)
        } catch {
            ELOG("DeltaSkinExporter: failed to zip to \(outputURL.lastPathComponent): \(error)")
            throw DeltaSkinExportError.archiveCreationFailed
        }
    }
}
