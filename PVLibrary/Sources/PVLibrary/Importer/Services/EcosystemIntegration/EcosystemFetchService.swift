//
//  EcosystemFetchService.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 2026-07-09.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Downloads a ROM file set offered by an ecosystem app (currently iFly EMU)
//  after a user-confirmed `<app>://requestGame` handshake. The offering app
//  answers `provenance://<scheme>?fetch=<base64url JSON>` with a short-lived
//  HTTP session (bearer token) on the local device/network; this service
//  pulls the files into the ROM import directory, where the DirectoryWatcher
//  ingests them like any other drop.
//

import Foundation
import PVFileSystem
import PVLogging

// MARK: - EcosystemFetchPayload

/// The `fetch=` callback payload (field names fixed by iFly's
/// EcosystemBridge.FetchPayload).
public struct EcosystemFetchPayload: Codable, Sendable {
    public let name: String
    public let md5: String
    /// Base URLs to try, most-preferred first.
    public let bases: [String]
    public let manifestPath: String
    public let filePath: String
    public let fileQueryKey: String
    public let token: String
}

// MARK: - EcosystemFetchParser

/// Parses `provenance://<source_scheme>?fetch=<base64url_json>`.
public enum EcosystemFetchParser {
    public static func parse(url: URL) -> (source: EcosystemApp, payload: EcosystemFetchPayload)? {
        guard let scheme = url.host(percentEncoded: false),
              let source = EcosystemApp(rawValue: scheme),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fetchParam = components.queryItems?.first(where: { $0.name == "fetch" })?.value,
              let data = Data(base64urlEncoded: fetchParam),
              let payload = try? JSONDecoder().decode(EcosystemFetchPayload.self, from: data)
        else { return nil }
        return (source, payload)
    }
}

// MARK: - EcosystemFetchService

/// Pulls an offered file set into `Paths.romsImportPath`.
public actor EcosystemFetchService {
    public static let shared = EcosystemFetchService()

    /// Minimal projection of the offering app's manifest — only what the
    /// download needs (iFly's ContinuityManifest is a superset).
    private struct Manifest: Decodable {
        struct Entry: Decodable {
            let kind: String
            let relativePath: String
            let size: Int64
        }
        let files: [Entry]
    }

    public enum FetchError: Error {
        case unreachable
        case badManifest
        case httpStatus(Int)
    }

    /// Downloads the payload's game files. Returns the directory the files
    /// landed in (inside the import path — the watcher takes it from there).
    @discardableResult
    public func download(
        _ payload: EcosystemFetchPayload,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> URL {
        guard let (base, manifest) = try await firstReachableManifest(payload) else {
            throw FetchError.unreachable
        }
        // Game files only: BIOS and save state management stay each app's own
        // business. Relative structure is preserved below the container so
        // multi-file sets (GDI + tracks, Naomi zip + companion CHD) keep the
        // sibling layout their formats require.
        let wanted = manifest.files.filter { $0.kind == "gameFile" }
        guard !wanted.isEmpty else { throw FetchError.badManifest }

        let containerName = "iFly-\(String(payload.md5.prefix(8)))"
        let container = Paths.romsImportPath.appendingPathComponent(containerName, isDirectory: true)

        for (index, entry) in wanted.enumerated() {
            let destination = container.appendingPathComponent(entry.relativePath)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            var request = URLRequest(url: fileURL(base: base, payload: payload, relativePath: entry.relativePath))
            request.setValue("Bearer \(payload.token)", forHTTPHeaderField: "Authorization")
            let (temp, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                // (await: PVFileSystem's async removeItem overload wins here.)
                try? await FileManager.default.removeItem(at: temp)
                throw FetchError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
            }
            try? await FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temp, to: destination)
            progress?(index + 1, wanted.count)
            ILOG("EcosystemFetch: \(entry.relativePath) (\(index + 1)/\(wanted.count))")
        }
        ILOG("EcosystemFetch: '\(payload.name)' complete → \(container.lastPathComponent)")
        return container
    }

    // MARK: - Internals

    private func firstReachableManifest(
        _ payload: EcosystemFetchPayload
    ) async throws -> (URL, Manifest)? {
        for baseString in payload.bases {
            guard let base = URL(string: baseString) else { continue }
            var request = URLRequest(url: base.appendingPathComponent(payload.manifestPath))
            request.setValue("Bearer \(payload.token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                guard let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
                    throw FetchError.badManifest
                }
                return (base, manifest)
            } catch let error as FetchError {
                throw error
            } catch {
                continue // next base
            }
        }
        return nil
    }

    private func fileURL(base: URL, payload: EcosystemFetchPayload, relativePath: String) -> URL {
        var components = URLComponents(
            url: base.appendingPathComponent(payload.filePath),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: payload.fileQueryKey, value: relativePath)]
        return components?.url ?? base
    }
}

// MARK: - Notifications

public extension Notification.Name {
    /// An ecosystem app answered a gameInfo query.
    /// userInfo: "source" = EcosystemApp raw value, "games" = [EcosystemGameScheme].
    static let ecosystemGamesReceived = Notification.Name("PVEcosystemGamesReceived")
    /// An ecosystem ROM transfer finished downloading into the import path.
    /// userInfo: "source" = EcosystemApp raw value, "name", "path".
    static let ecosystemFetchCompleted = Notification.Name("PVEcosystemFetchCompleted")
}

// MARK: - base64url

private extension Data {
    /// base64url (RFC 4648 §5) with optional padding restored.
    init?(base64urlEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }
}
