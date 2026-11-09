//
//  ECSSource.swift
//  PVLibrarySharing
//
//  Client for Provenance-Emu/emulator-content-server (spec §1.4, §3.7, phase 5).
//

import Foundation
import EmulatorContentClient
import PVSystems

/// Where an `ECSSource` keeps its token between launches. The app backs it
/// with the Keychain; tests use memory.
public protocol ECSTokenStore: Sendable {
    func token(for server: URL) -> String?
    func setToken(_ token: String?, for server: URL)
}

/// A content server's generated Swift models adapted to `LibrarySource`.
///
/// Browses `/api/v1/browse-libraries` and cursor-paged game entries, including
/// managed items and indexed roots. Manifests and authentication use the generated
/// client types; `LibraryPuller` owns verified staging and resumable transfers.
/// Stored read tokens are preferred. Password sign-in mints a read-scoped device
/// token when permitted, falling back to the session token for non-admin readers.
public actor ECSSource: LibrarySource {
    public static let supportedMajor = 1
    static let romKind = "rom"
    static let readScope = "read"

    public nonisolated let app: PeerApp = .contentServer

    private let server: URL
    private let username: String
    private let password: String?
    private let deviceName: String
    private let systems: Set<SystemIdentifier>?
    private let tokens: any ECSTokenStore
    private let transport: any LibraryHTTPTransport
    private var token: String?
    private var pageSize = 100
    private var indexedSources: [String: EmulatorContentClient.SourceFile] = [:]
    private var preparedFiles: [String: URL] = [:]
    private let preparationRoot = FileManager.default.temporaryDirectory.appendingPathComponent("ecs-" + UUID().uuidString)

    deinit { try? FileManager.default.removeItem(at: preparationRoot) }

    /// - Parameters:
    ///   - server: the base URL, e.g. `https://ecs.local:8443`.
    ///   - password: nil when a stored token is expected to work.
    ///   - deviceName: names the device token on the server ("Provenance on iPhone").
    public init(
        server: URL,
        username: String,
        password: String?,
        deviceName: String,
        systems: Set<SystemIdentifier>? = nil,
        tokens: any ECSTokenStore,
        transport: any LibraryHTTPTransport = URLSessionLibraryTransport(followsRedirects: false)
    ) {
        self.server = server
        self.username = username
        self.password = password
        self.deviceName = deviceName
        self.systems = systems
        self.tokens = tokens
        self.transport = transport
    }

    // MARK: - Wire

    typealias Capabilities = EmulatorContentClient.Capabilities
    typealias LoginRequest = EmulatorContentClient.LoginRequest
    typealias Session = EmulatorContentClient.SessionResponse
    typealias DeviceTokenDraft = EmulatorContentClient.DeviceTokenDraft
    typealias DeviceTokenCreated = EmulatorContentClient.DeviceTokenCreated
    typealias Library = EmulatorContentClient.Library
    typealias Item = EmulatorContentClient.Item
    typealias Manifest = EmulatorContentClient.Manifest

    struct Page<Item: Decodable>: Decodable {
        var items: [Item]
        var nextCursor: String?
    }

    /// Libraries visible to the current token, for the app's library picker.
    public func libraries() async throws -> [EmulatorContentClient.Library] {
        try await checkCapabilities()
        return try await pages(path: "/api/v1/browse-libraries", query: [])
    }

    // MARK: - LibrarySource

    public func catalogue(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteCatalogue {
        try await catalogue(libraryID: nil, progress: progress)
    }

    /// A selected library, or every accessible library when nil.
    public func catalogue(libraryID: String?, progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteCatalogue {
        progress(.connecting)
        let libraries = try await libraries()
        progress(.loadingCatalogue)
        var items: [RemoteLibraryItem] = []
        for library in libraries where libraryID == nil || library.id == libraryID {
            let query = [URLQueryItem(name: "libraryId", value: library.id), URLQueryItem(name: "category", value: "games")]
            let page: [EmulatorContentClient.LibraryBrowseEntry] = try await pages(path: "/api/v1/browse", query: query)
            for entry in page {
                if let item = entry.item, entry.entityType == "item" {
                    items.append(Self.item(item))
                } else if let file = entry.source, entry.entityType == "source", let system = file.systemId {
                    let id = "source:" + file.id
                    indexedSources[id] = file
                    items.append(RemoteLibraryItem(id: id, title: file.title ?? entry.name, platform: system,
                                                  systemIdentifier: SystemMap.systemIdentifier(compact: system),
                                                  md5: nil, sizeBytes: file.size, artKey: nil, source: .contentServer))
                }
            }
        }
        let catalogue = RemoteCatalogue(deviceName: server.host ?? server.absoluteString, items: items, source: .contentServer)
        return systems.map { catalogue.filtered(to: $0) } ?? catalogue
    }

    static func item(_ item: Item) -> RemoteLibraryItem {
        RemoteLibraryItem(
            id: item.id, title: item.title, platform: item.systemIdentifier,
            systemIdentifier: SystemMap.systemIdentifier(compact: item.systemIdentifier),
            md5: item.md5, sizeBytes: 0, artKey: nil, source: .contentServer
        )
    }

    public func artwork(for item: RemoteLibraryItem) async throws -> Data? { nil }

    public func pullManifest(
        for item: RemoteLibraryItem,
        progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> RemoteManifest {
        progress(.connecting)
        if let source = indexedSources[item.id] {
            return try await prepareIndexedManifest(source, itemID: item.id, progress: progress)
        }
        // appendingPathComponent percent-encodes the id itself.
        let url = server.appendingRoute("/api/v1/items").appendingPathComponent(item.id).appendingPathComponent("manifest")
        let response = try await authorized(LibraryHTTPRequest(url: url))
        switch response.status {
        case 200:
            let manifest = try JSONDecoder().decode(Manifest.self, from: response.body)
            guard manifest.version == 1, manifest.itemId == item.id else { throw LibrarySharingError.itemUnavailable }
            return Self.manifest(manifest, itemId: item.id)
        case 403, 404:
            throw LibrarySharingError.itemUnavailable
        default:
            throw Self.error(forStatus: response.status)
        }
    }

    /// `rom` becomes a game file; every other kind keeps its name and is left
    /// behind by the puller (BIOS needs the user's say-so; states don't load).
    static func manifest(_ manifest: Manifest, itemId: String) -> RemoteManifest {
        RemoteManifest(itemId: itemId, files: manifest.files.map { file in
            RemoteFile(
                kind: file.kind == romKind ? RemoteFile.gameFileKind : file.kind,
                relativePath: file.relativePath, sha256: file.sha256, size: file.size,
                required: file.required, contentPath: "/api/v1/files/\(file.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? file.id)/content"
            )
        })
    }

    public func download(
        _ file: RemoteFile,
        of manifest: RemoteManifest,
        to partialFile: URL,
        resumeOffset: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> LibraryDownloadResponse {
        guard let contentPath = file.contentPath, let url = URL(string: contentPath, relativeTo: server)?.absoluteURL,
              url.scheme == server.scheme, url.host == server.host, url.port == server.port,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              (url.path.hasPrefix("/api/v1/files/") || url.path.hasPrefix("/api/v1/sources/")), url.path.hasSuffix("/content") else {
            throw LibrarySharingError.unsafePath(file.contentPath ?? file.relativePath)
        }
        if let prepared = preparedFiles[contentPath] {
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: partialFile.path) { try FileManager.default.removeItem(at: partialFile) }
            try FileManager.default.copyItem(at: prepared, to: partialFile)
            try Task.checkCancellation()
            progress(file.size)
            preparedFiles[contentPath] = nil
            try? FileManager.default.removeItem(at: prepared)
            return LibraryDownloadResponse(status: 200, writtenFrom: 0, bytesOnDisk: file.size)
        }
        for attempt in 0..<2 {
            let token = try await currentToken()
            guard token.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else { throw LibrarySharingError.signInFailed }
            let response = try await transport.download(
                .authorizedGet(url: url, token: token), to: partialFile, resumeOffset: resumeOffset, progress: progress
            )
            if isPullerHandledDownloadStatus(response.status) { return response }
            if response.status == 401, attempt == 0 {
                forgetToken()
                continue
            }
            if response.status == 404 || response.status == 403 { throw LibrarySharingError.fileUnavailable(file.fileName) }
            throw Self.error(forStatus: response.status)
        }
        throw LibrarySharingError.signInFailed
    }

    /// Indexed roots have no remote digest. Stream once into private scratch space,
    /// compute a local digest, then let the normal puller verify/import that exact copy.
    private func prepareIndexedManifest(
        _ source: EmulatorContentClient.SourceFile,
        itemID: String,
        progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> RemoteManifest {
        guard source.availability == "local" else { throw LibrarySharingError.itemUnavailable }
        var files: [EmulatorContentClient.SourceGroupFile]
        if (source.groupFileCount ?? 0) > 0 || ["cue", "gdi", "m3u", "ccd"].contains((source.name as NSString).pathExtension.lowercased()) {
            let url = server.appendingRoute("/api/v1/sources").appendingPathComponent(source.id).appendingPathComponent("group")
            let response = try await authorized(LibraryHTTPRequest(url: url))
            guard response.status == 200 else { throw Self.error(forStatus: response.status) }
            let group = try JSONDecoder().decode(EmulatorContentClient.SourceGroup.self, from: response.body)
            guard group.sourceId == source.id, group.error == nil else { throw LibrarySharingError.itemUnavailable }
            files = group.files
        } else {
            files = [.init(id: source.id, name: source.name, relativePath: source.name, size: source.size, availability: source.availability)]
        }
        guard !files.isEmpty, files.count <= 512 else { throw LibrarySharingError.nothingToCopy }
        var names = Set<String>()
        var total: Int64 = 0
        for file in files {
            let path = file.relativePath ?? file.name
            guard file.availability == "local", file.size >= 0, file.size <= (8 << 30) - total,
                  LibraryStaging.containedURL(for: path, in: preparationRoot) != nil,
                  names.insert(path.lowercased()).inserted else { throw LibrarySharingError.unsafePath(path) }
            total += file.size
        }
        progress(.loadingCatalogue)
        try FileManager.default.createDirectory(at: preparationRoot, withIntermediateDirectories: true)
        var manifestFiles: [RemoteFile] = []
        var added: [String] = []
        do {
            for file in files {
                try Task.checkCancellation()
                let endpoint = "/api/v1/sources/" + (file.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? file.id) + "/content"
                let temporary = preparationRoot.appendingPathComponent(UUID().uuidString)
                defer { if !preparedFiles.values.contains(temporary) { try? FileManager.default.removeItem(at: temporary) } }
                let remote = RemoteFile(kind: RemoteFile.gameFileKind, relativePath: file.relativePath ?? file.name,
                                        sha256: "", size: file.size, contentPath: endpoint)
                preparedFiles[endpoint] = nil
                let response = try await download(remote, of: RemoteManifest(itemId: itemID, files: []),
                                                  to: temporary, resumeOffset: 0) { _ in }
                guard response.status == 200, response.bytesOnDisk == file.size else {
                    try? FileManager.default.removeItem(at: temporary)
                    throw LibrarySharingError.fileUnavailable(file.name)
                }
                var verified = remote
                verified.sha256 = try FileSHA256.hex(of: temporary)
                preparedFiles[endpoint] = temporary
                added.append(endpoint)
                manifestFiles.append(verified)
            }
            return RemoteManifest(itemId: itemID, files: manifestFiles)
        } catch {
            for endpoint in added {
                if let path = preparedFiles.removeValue(forKey: endpoint) { try? FileManager.default.removeItem(at: path) }
            }
            throw error
        }
    }

    // MARK: - Requests

    private func checkCapabilities() async throws {
        let response = try await transport.send(LibraryHTTPRequest(url: server.appendingRoute("/api/v1/capabilities")))
        guard response.status == 200 else { throw Self.error(forStatus: response.status) }
        let capabilities = try JSONDecoder().decode(Capabilities.self, from: response.body)
        guard capabilities.protocol.major == Self.supportedMajor else {
            throw LibrarySharingError.unsupportedServer("protocol \(capabilities.protocol.major).\(capabilities.protocol.minor)")
        }
        pageSize = max(1, capabilities.limits.maxPageSize)
    }

    /// Every page of a cursor-paged list.
    private func pages<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> [T] {
        var all: [T] = []
        var cursor: String?
        var seen = Set<String>()
        repeat {
            try Task.checkCancellation()
            var components = URLComponents(url: server.appendingRoute(path), resolvingAgainstBaseURL: false)
            components?.queryItems = query + [URLQueryItem(name: "limit", value: String(pageSize))]
                + (cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? [])
            guard let url = components?.url else { throw LibrarySharingError.unreachable }
            let response = try await authorized(LibraryHTTPRequest(url: url))
            guard response.status == 200 else { throw Self.error(forStatus: response.status) }
            let page = try JSONDecoder().decode(Page<T>.self, from: response.body)
            all += page.items
            cursor = page.nextCursor
            if let cursor, !seen.insert(cursor).inserted { throw LibrarySharingError.invalidResponse(status: 200) }
        } while cursor != nil
        return all
    }

    /// Sends with the bearer token, signing in again once on 401.
    private func authorized(_ request: LibraryHTTPRequest) async throws -> LibraryHTTPResponse {
        for attempt in 0..<2 {
            var signed = request
            signed.headers["Authorization"] = "Bearer \(try await currentToken())"
            guard signed.headers["Authorization"]?.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) == true else { throw LibrarySharingError.signInFailed }
            let response = try await transport.send(signed)
            if response.status == 401, attempt == 0 {
                forgetToken()
                continue
            }
            return response
        }
        throw LibrarySharingError.signInFailed
    }

    private func currentToken() async throws -> String {
        if let token { return token }
        if let stored = tokens.token(for: server) {
            token = stored
            return stored
        }
        let fresh = try await signIn()
        token = fresh
        tokens.setToken(fresh, for: server)
        return fresh
    }

    private func forgetToken() {
        token = nil
        tokens.setToken(nil, for: server)
    }

    /// Login, then a read-scoped device token; the session token when the
    /// account may not mint one.
    private func signIn() async throws -> String {
        guard let password else { throw LibrarySharingError.signInFailed }
        let login = try await transport.send(.jsonPost(
            url: server.appendingRoute("/api/v1/auth/login"), body: LoginRequest(username: username, password: password)
        ))
        guard login.status == 200 else {
            throw login.status == 401 ? LibrarySharingError.signInFailed : Self.error(forStatus: login.status)
        }
        let session = try JSONDecoder().decode(Session.self, from: login.body).token
        var mint = try LibraryHTTPRequest.jsonPost(
            url: server.appendingRoute("/api/v1/device-tokens"),
            body: DeviceTokenDraft(name: deviceName, scopes: [Self.readScope], expiresInSeconds: nil)
        )
        mint.headers["Authorization"] = "Bearer \(session)"
        let minted = try await transport.send(mint)
        if minted.status == 201 || minted.status == 200,
           let device = try? JSONDecoder().decode(DeviceTokenCreated.self, from: minted.body) {
            return device.token
        }
        return session
    }

    static func error(forStatus status: Int) -> LibrarySharingError {
        switch status {
        case 401: return .signInFailed
        case 403: return .declined
        case 404: return .sharingUnavailable
        default: return .invalidResponse(status: status)
        }
    }
}

/// In-memory token store for tests and previews.
public final class InMemoryECSTokenStore: ECSTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [URL: String] = [:]

    public init() {}

    public func token(for server: URL) -> String? {
        lock.withLock { tokens[server] }
    }

    public func setToken(_ token: String?, for server: URL) {
        lock.withLock { tokens[server] = token }
    }
}

#if canImport(Security)
import Security

/// Keychain-backed tokens, one generic-password item per server URL. A token
/// opens the user's whole library on that server, so it never goes in
/// UserDefaults or Documents.
public struct KeychainECSTokenStore: ECSTokenStore {
    public static let service = "org.provenance-emu.content-server"

    public init() {}

    private func query(_ server: URL) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: server.absoluteString
        ]
    }

    public func token(for server: URL) -> String? {
        var request = query(server)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func setToken(_ token: String?, for server: URL) {
        SecItemDelete(query(server) as CFDictionary)
        guard let token else { return }
        var item = query(server)
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
#endif
