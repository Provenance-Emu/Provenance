import Foundation
import ZIPFoundation

/// Severity level for validation findings
public enum DeltaSkinValidationSeverity {
    case info
    case warning
    case error
}

/// A single validation finding with an actionable suggestion
public struct DeltaSkinValidationFinding: Identifiable {
    public let id = UUID()
    public let severity: DeltaSkinValidationSeverity
    public let title: String
    public let detail: String
    public let suggestion: String?

    public init(severity: DeltaSkinValidationSeverity, title: String, detail: String, suggestion: String?) {
        self.severity = severity
        self.title = title
        self.detail = detail
        self.suggestion = suggestion
    }
}

/// Result of validating a skin archive
public struct DeltaSkinValidationResult: Identifiable {
    /// Stable identifier for use as sheet item
    public let id = UUID()
    public let findings: [DeltaSkinValidationFinding]

    public var errors: [DeltaSkinValidationFinding] { findings.filter { $0.severity == .error } }
    public var warnings: [DeltaSkinValidationFinding] { findings.filter { $0.severity == .warning } }
    public var infos: [DeltaSkinValidationFinding] { findings.filter { $0.severity == .info } }

    /// True when there are no error-level findings
    public var isValid: Bool { errors.isEmpty }
}

/// Validates a .deltaskin or .manicskin ZIP archive and returns actionable findings
public struct DeltaSkinValidator {

    public static func validate(url: URL) -> DeltaSkinValidationResult {
        var findings: [DeltaSkinValidationFinding] = []

        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return DeltaSkinValidationResult(findings: [
                DeltaSkinValidationFinding(
                    severity: .error,
                    title: "File not found",
                    detail: "The skin file does not exist at the specified path.",
                    suggestion: "Ensure the file was imported correctly."
                )
            ])
        }

        // Check extension
        let ext = url.pathExtension.lowercased()
        guard ext == "deltaskin" || ext == "manicskin" else {
            findings.append(DeltaSkinValidationFinding(
                severity: .error,
                title: "Unsupported file type",
                detail: "Expected .deltaskin or .manicskin, got .\(ext)",
                suggestion: "Rename the file with the correct extension."
            ))
            return DeltaSkinValidationResult(findings: findings)
        }

        // Try to open ZIP archive
        guard let archive = Archive(url: url, accessMode: .read) else {
            return DeltaSkinValidationResult(findings: findings + [
                DeltaSkinValidationFinding(
                    severity: .error,
                    title: "Invalid archive",
                    detail: "The file is not a valid ZIP archive or is corrupted.",
                    suggestion: "Re-download or re-create the skin file."
                )
            ])
        }

        // Collect all entry paths
        var entryNames = Set<String>()
        for entry in archive {
            entryNames.insert(entry.path)
        }

        // Check info.json exists at root
        guard entryNames.contains("info.json") else {
            return DeltaSkinValidationResult(findings: findings + [
                DeltaSkinValidationFinding(
                    severity: .error,
                    title: "Missing info.json",
                    detail: "The skin archive must contain an info.json file at the root level.",
                    suggestion: "Add info.json with required fields: identifier, name, gameTypeIdentifier, representations."
                )
            ])
        }

        // Extract info.json
        var extractedData = Data()
        if let infoEntry = archive["info.json"] {
            _ = try? archive.extract(infoEntry) { chunk in extractedData.append(chunk) }
        }

        guard !extractedData.isEmpty else {
            findings.append(DeltaSkinValidationFinding(
                severity: .error,
                title: "Empty info.json",
                detail: "info.json is empty.",
                suggestion: "Add required skin metadata to info.json."
            ))
            return DeltaSkinValidationResult(findings: findings)
        }

        // Parse as JSON
        guard let json = try? JSONSerialization.jsonObject(with: extractedData) as? [String: Any] else {
            findings.append(DeltaSkinValidationFinding(
                severity: .error,
                title: "Invalid JSON in info.json",
                detail: "info.json contains invalid JSON.",
                suggestion: "Validate your JSON using a linter such as jsonlint.com."
            ))
            return DeltaSkinValidationResult(findings: findings)
        }

        // Check required top-level fields
        let requiredFields = ["identifier", "name", "gameTypeIdentifier", "representations"]
        for field in requiredFields {
            if json[field] == nil {
                findings.append(DeltaSkinValidationFinding(
                    severity: .error,
                    title: "Missing required field: \(field)",
                    detail: "info.json must contain '\(field)'.",
                    suggestion: "Add the '\(field)' field to info.json."
                ))
            }
        }

        // Warn about missing optional but recommended field
        if json["debug"] == nil {
            findings.append(DeltaSkinValidationFinding(
                severity: .error,
                title: "Missing 'debug' field",
                detail: "info.json should include a debug flag.",
                suggestion: "Add \"debug\": false to info.json."
            ))
        }

        // Check asset file references inside representations
        if let representations = json["representations"] as? [String: Any] {
            checkAssetReferences(in: representations, entryNames: entryNames, findings: &findings)
        }

        // All good
        if findings.isEmpty {
            findings.append(DeltaSkinValidationFinding(
                severity: .info,
                title: "Skin is valid",
                detail: "No issues found.",
                suggestion: nil
            ))
        }

        return DeltaSkinValidationResult(findings: findings)
    }

    // MARK: - Private helpers

    private static func checkAssetReferences(
        in representations: [String: Any],
        entryNames: Set<String>,
        findings: inout [DeltaSkinValidationFinding]
    ) {
        for (device, deviceRep) in representations {
            guard let deviceDict = deviceRep as? [String: Any] else { continue }
            for (displayType, displayRep) in deviceDict {
                guard let displayDict = displayRep as? [String: Any] else { continue }
                for (orientation, orientationRep) in displayDict {
                    guard let orientDict = orientationRep as? [String: Any],
                          let assets = orientDict["assets"] as? [String: Any] else { continue }
                    let context = "\(device)/\(displayType)/\(orientation)"
                    for (_, assetValue) in assets {
                        if let assetName = assetValue as? String, !assetName.isEmpty {
                            if !entryNames.contains(assetName) {
                                findings.append(DeltaSkinValidationFinding(
                                    severity: .error,
                                    title: "Missing asset: \(assetName)",
                                    detail: "Asset '\(assetName)' referenced in \(context) does not exist in the archive.",
                                    suggestion: "Add the file '\(assetName)' to the skin archive."
                                ))
                            }
                        }
                    }
                }
            }
        }
    }
}
