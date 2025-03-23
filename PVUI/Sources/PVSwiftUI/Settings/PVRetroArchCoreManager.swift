import Foundation
import PVHashing

@MainActor
public final class PVRetroArchCoreManager {
    public static let shared = PVRetroArchCoreManager()

    private init() {}

    /// Checks if RetroArch core is installed
    public var isRetroArchInstalled: Bool {
        Bundle.allFrameworks.contains { $0.bundleIdentifier == "org.provenance-emu.coresretro.pvretroarchcore" }
    }

    /// Returns URL of the bundled retroarch.cfg if it exists
    public var bundledConfigURL: URL? {
        guard let bundle = Bundle.allFrameworks.first(where: { $0.bundleIdentifier == "org.provenance-emu.coresretro.pvretroarchcore" }),
              let url = bundle.url(forResource: "retroarch", withExtension: "cfg") else {
            return nil
        }
        return url
    }

    /// Returns the contents of the bundled retroarch.cfg as a string if it exists
    public var bundledConfigContents: String? {
        guard let url = bundledConfigURL else { return nil }
        return try? String(contentsOf: url)
    }

    /// Parses the retroarch.cfg file into a dictionary
    public func parseConfigFile(at url: URL) async -> [String: String] {
        guard let contents = try? String(contentsOf: url) else { return [:] }

        var configDict = [String: String]()
        let lines = contents.components(separatedBy: .newlines)

        for line in lines {
            let components = line.components(separatedBy: "=")
            if components.count == 2 {
                let key = components[0].trimmingCharacters(in: .whitespaces)
                let value = components[1].trimmingCharacters(in: .whitespaces)
                configDict[key] = value
            }
        }

        return configDict
    }

    /// Gets the MD5 hash of a file at a given URL
    public func md5Hash(for url: URL) async -> String? {
        return FileManager.default.md5ForFile(at: url, fromOffset: 0)
    }

    /// Returns the active config file URL in Documents directory
    public var activeConfigURL: URL? {
        #if os(tvOS)
        let documentsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return documentsURL?.appendingPathComponent("RetroArch/config/retroarch.cfg")
        #else
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsURL?.appendingPathComponent("RetroArch/config/retroarch.cfg")
        #endif
    }

    /// Returns the version string of the newest retroarch.cfg in Documents
    public var newestConfigVersion: String? {
        #if os(tvOS)
        guard let documentsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        #else
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        #endif

        let configURL = documentsURL.appendingPathComponent("RetroArch/config")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: configURL, includingPropertiesForKeys: nil) else {
            return nil
        }

        let configFiles = contents.filter { $0.pathExtension == "cfg" }
        let versions = configFiles.compactMap { $0.deletingPathExtension().lastPathComponent }

        return versions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }.first
    }

    /// Checks if the active config needs to be reset
    public func shouldResetConfig() async -> Bool {
        guard let bundledURL = bundledConfigURL,
              let activeURL = activeConfigURL,
              FileManager.default.fileExists(atPath: activeURL.path) else {
            return true
        }

        guard let bundledHash = await md5Hash(for: bundledURL),
              let activeHash = await md5Hash(for: activeURL) else {
            return true
        }

        return bundledHash != activeHash
    }

    /// Safely copies a file, overwriting the destination if it exists
    public func copyConfigFile(from sourceURL: URL, to destinationURL: URL) async throws {
        // Create intermediate directories if they don't exist
        let destinationDir = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        // Copy the new file
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    /// Downloads and caches the default retroarch.cfg from GitHub
    public func downloadDefaultConfig() async throws -> String {
        let url = URL(string: "https://raw.githubusercontent.com/libretro/RetroArch/refs/heads/master/retroarch.cfg")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Parses the config file comments to get descriptions for keys
    public func parseConfigDescriptions(_ contents: String) async -> [String: String] {
        var descriptions = [String: String]()
        let lines = contents.components(separatedBy: .newlines)
        var currentDescription = ""

        for line in lines {
            if line.hasPrefix("#") {
                // Remove # and trim whitespace
                let descriptionLine = line.dropFirst().trimmingCharacters(in: .whitespaces)
                currentDescription += descriptionLine + "\n"
            } else if line.contains("=") {
                let key = line.components(separatedBy: "=")[0].trimmingCharacters(in: .whitespaces)
                if !currentDescription.isEmpty {
                    descriptions[key] = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    currentDescription = ""
                }
            }
        }

        return descriptions
    }

    /// Detects the type of a config value
    public func detectValueType(_ value: String) -> ConfigValueType {
        if value.lowercased() == "true" || value.lowercased() == "false" {
            return .bool
        } else if value.contains("."), Double(value) != nil {
            return .float
        } else if Int(value) != nil {
            return .int
        }
        return .string
    }

    public enum ConfigValueType {
        case bool, int, float, string
    }
}
