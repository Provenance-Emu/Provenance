//
//  ECSSource.swift
//  PVLibrarySharing
//
//  Client for Provenance-Emu/emulator-content-server (spec §1.4, §3.7, phase 5).
//

import Foundation
import PVSystems

/// Where an `ECSSource` keeps its token between launches. The app backs it
/// with the Keychain; tests use memory.
public protocol ECSTokenStore: Sendable {
    func token(for server: URL) -> String?
    func setToken(_ token: String?, for server: URL)
}

/// A content server's `/api/v1`, behind the same `LibrarySource` as the app
/// peers, so browsing and `LibraryPuller` work unchanged:
///
/// - `GET /api/v1/capabilities`: protocol major must be 1; `maxPageSize` sets
///   the page size.
/// - Auth: a stored token, else `POST auth/login {username,password}` → a
///   session token, then `POST device-tokens {name, scopes:["read"]}` for a
///   long-lived read token. Minting needs `admin` scope, so a reader falls
///   back to the session token (spec §3.7). A 401 later signs in again once.
/// - `GET /api/v1/libraries`, then `GET /api/v1/items?libraryId=&limit=&cursor=`
///   per library. The server has no system filter yet, so items are filtered
///   locally to `systems`.
/// - `GET /api/v1/items/{id}/manifest`: files with `kind` `rom` (→ game file),
///   `bios`, `save_state`…; only game files are copied.
/// - `GET <contentPath>` with Range: 206, or 200 meaning start over (as ECS's
///   own `ResumePlanner`).
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
        transport: any LibraryHTTPTransport = URLSessionLibraryTransport()
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

    struct Capabilities: Decodable {
        struct ProtocolInfo: Decodable {
            var major: Int
            var minor: Int
        }

        struct Limits: Decodable {
            var maxPageSize: Int
        }

        var `protocol`: ProtocolInfo
        var limits: Limits
    }

    struct LoginRequest: Encodable {
        var username: String
        var password: String
    }

    struct Session: Decodable {
        var token: String
    }

    struct DeviceTokenDraft: Encodable {
        var name: String
        var scopes: [String]
        var expiresInSeconds: Int?
    }

    struct DeviceTokenCreated: Decodable {
        var token: String
    }

    struct Page<Item: Decodable>: Decodable {
        var items: [Item]
        var nextCursor: String?
    }

    struct Library: Decodable {
        var id: String
        var name: String
    }

    struct Item: Decodable {
        var id: String
        var systemIdentifier: String
        var title: String
        var md5: String?
    }

    struct Manifest: Decodable {
        struct File: Decodable {
            var kind: String
            var relativePath: String
            var sha256: String
            var size: Int64
            var required: Bool
            var contentPath: String
        }

        var version: Int
        var itemId: String
        var files: [File]
    }

    // MARK: - LibrarySource

    public func catalogue(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteCatalogue {
        progress(.connecting)
        try await checkCapabilities()
        progress(.loadingCatalogue)
        let libraries: [Library] = try await pages(path: "/api/v1/libraries", query: [])
        var items: [RemoteLibraryItem] = []
        for library in libraries {
            let page: [Item] = try await pages(path: "/api/v1/items", query: [URLQueryItem(name: "libraryId", value: library.id)])
            items += page.map(Self.item)
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
        // appendingPathComponent percent-encodes the id itself.
        let url = server.appendingRoute("/api/v1/items").appendingPathComponent(item.id).appendingPathComponent("manifest")
        let response = try await authorized(LibraryHTTPRequest(url: url))
        switch response.status {
        case 200:
            return Self.manifest(try JSONDecoder().decode(Manifest.self, from: response.body), itemId: item.id)
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
                required: file.required, contentPath: file.contentPath
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
              url.host == server.host else {
            throw LibrarySharingError.unsafePath(file.contentPath ?? file.relativePath)
        }
        for attempt in 0..<2 {
            let token = try await currentToken()
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
        repeat {
            var components = URLComponents(url: server.appendingRoute(path), resolvingAgainstBaseURL: false)
            components?.queryItems = query + [URLQueryItem(name: "limit", value: String(pageSize))]
                + (cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? [])
            guard let url = components?.url else { throw LibrarySharingError.unreachable }
            let response = try await authorized(LibraryHTTPRequest(url: url))
            guard response.status == 200 else { throw Self.error(forStatus: response.status) }
            let page = try JSONDecoder().decode(Page<T>.self, from: response.body)
            all += page.items
            cursor = page.nextCursor
        } while cursor != nil
        return all
    }

    /// Sends with the bearer token, signing in again once on 401.
    private func authorized(_ request: LibraryHTTPRequest) async throws -> LibraryHTTPResponse {
        for attempt in 0..<2 {
            var signed = request
            signed.headers["Authorization"] = "Bearer \(try await currentToken())"
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
