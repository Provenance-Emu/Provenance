//
//  IFlyDialectServer.swift
//  PVLibrarySharing
//
//  Provenance answering an unmodified iFly client (spec §3.1, phase 3).
//

import Foundation
import PVSystems

/// iFly's library routes, as `ContinuityLibraryServer` (iFly ContinuityKit)
/// answers them:
///
/// - `POST library/auth/start` and `auth/complete`: consent auth (`ConsentGate`).
/// - `GET library/manifest`: the whole catalogue with an `ETag`; 304 on a
///   matching `If-None-Match`.
/// - `GET library/art?key=`: art bytes; keys with `/`, `\` or `..` are 400.
/// - `POST library/pull {gameId}`: a pull manifest; 202/403 while "Ask per
///   game" runs. Never 429: Provenance meters nothing.
/// - `GET library/file?path=`: Range-aware, only paths of a granted pull.
///
/// Every route answers 404 while sharing is off, as iFly does. Only Dreamcast,
/// NAOMI, NAOMI 2 and Atomiswave games are listed.
public actor IFlyDialectServer {
    static let romsFolder = "ROMs"

    /// A file a granted pull may fetch.
    private struct Granted {
        let url: URL
        let size: Int64
    }

    private let identity: PeerIdentity
    private let device: HostDevice
    private let library: any SharedLibraryProviding
    private let hashes: FileHashCache
    private let sharingEnabled: @Sendable () async -> Bool
    private let gate: ConsentGate
    /// Every granted pull's files by relative path: the file route's allowlist.
    private var allowlist: [String: Granted] = [:]

    public init(
        identity: PeerIdentity,
        device: HostDevice,
        library: any SharedLibraryProviding,
        trust: any HostTrustStore,
        approver: any LibraryHostApproving,
        hashes: FileHashCache,
        sharingEnabled: @escaping @Sendable () async -> Bool
    ) {
        self.identity = identity
        self.device = device
        self.library = library
        self.hashes = hashes
        self.sharingEnabled = sharingEnabled
        self.gate = ConsentGate(identity: identity, domain: .iFly, app: .iFly, trust: trust, approver: approver)
    }

    /// Drops every token and pending request (sharing off, trust edited).
    public func revokeAll() async {
        allowlist.removeAll()
        await gate.revokeAll()
    }

    public func revoke(peerId: String) async {
        await gate.revoke(peerId: peerId)
    }

    public func handle(_ request: ServerRequest) async -> ServerResponse {
        guard await sharingEnabled() else { return .error(404, "library sharing unavailable") }
        switch (request.method, request.path) {
        case ("POST", ContinuityRoutes.libraryAuthStart): return await gate.start(request)
        case ("POST", ContinuityRoutes.libraryAuthComplete): return await gate.complete(request)
        default: break
        }
        guard let peerId = await gate.peer(forAuthorization: request.header("Authorization")) else {
            return .error(401, "invalid or missing library token")
        }
        switch (request.method, request.path) {
        case ("GET", ContinuityRoutes.iFlyLibraryManifest): return await catalogue(request)
        case ("GET", ContinuityRoutes.libraryArt): return await art(request)
        case ("POST", ContinuityRoutes.iFlyLibraryPull): return await pull(request, peerId: peerId)
        case ("GET", ContinuityRoutes.libraryFile): return file(request)
        default: return .error(404, "not found")
        }
    }

    // MARK: - Catalogue

    private func servedGames() async -> [(game: SharedGame, wire: IFlyWireLibraryManifest.Game)] {
        await library.sharedGames().compactMap { game in
            guard let platform = SystemMap.wirePlatform(for: game.system, app: .iFly), !game.files.isEmpty else { return nil }
            return (game, IFlyWireLibraryManifest.Game(
                title: game.title, platform: platform, md5: game.md5, sizeBytes: game.sizeBytes,
                artKey: game.hasArtwork ? Self.artKey(for: game) : nil, saveStateCount: 0
            ))
        }
    }

    /// A file-name-safe art key: the hex MD5, else a hash of the id.
    static func artKey(for game: SharedGame) -> String {
        game.md5 ?? FileSHA256.hex(of: Data(game.id.utf8))
    }

    private func catalogue(_ request: ServerRequest) async -> ServerResponse {
        // v1.1 filter and paging are additive: iFly itself sends neither.
        let query = CatalogueQuery(query: request.query)
        let games = await servedGames().filter { query.admits($0.game.system) }.map(\.wire).sorted { $0.id < $1.id }
        let version = IFlyWireLibraryManifest.version(of: games)
        if query.cursor == nil, request.header("If-None-Match") == version {
            return ServerResponse(status: 304)
        }
        guard let page = try? query.page(games, version: version) else {
            return .error(410, "the catalogue changed; start from the first page")
        }
        let manifest = IFlyWireLibraryManifest(
            peerId: identity.id, deviceName: device.name, games: page.items, catalogVersion: version, nextCursor: page.nextCursor
        )
        guard let data = try? JSONEncoder().encode(manifest) else { return .error(500, "library manifest build failed") }
        return .json(data, headers: ["ETag": version])
    }

    private func art(_ request: ServerRequest) async -> ServerResponse {
        guard let key = request.query[ContinuityRoutes.keyQueryItem], !key.isEmpty else {
            return .error(400, "missing ?key=")
        }
        guard !key.contains("/"), !key.contains("\\"), !key.contains("..") else {
            return .error(400, "invalid art key")
        }
        guard let game = await servedGames().first(where: { $0.game.hasArtwork && Self.artKey(for: $0.game) == key })?.game,
              let data = await library.artwork(forGameId: game.id) else {
            return .error(404, "no artwork for key")
        }
        return ServerResponse(status: 200, headers: ["Content-Type": "application/octet-stream"], body: .data(data))
    }

    // MARK: - Pull

    private func pull(_ request: ServerRequest, peerId: String) async -> ServerResponse {
        guard let body: IFlyPullRequest = decodeBody(request) else { return .error(400, "invalid pull request") }
        guard let game = await servedGames().first(where: { $0.wire.id == body.gameId })?.game else {
            return .error(404, "no such library game")
        }
        if let interim = await gate.pullApproval(peerId: peerId, gameId: body.gameId, gameTitle: game.title) {
            return interim
        }
        do {
            var descriptors: [WireFileDescriptor] = []
            for (relativePath, file) in Self.layout(of: game) {
                let sha = try await hashes.sha256(of: file.url)
                descriptors.append(WireFileDescriptor(
                    kind: RemoteFile.gameFileKind, relativePath: relativePath, sha256: sha, size: file.size, required: true
                ))
                allowlist[relativePath] = Granted(url: file.url, size: file.size)
            }
            let manifest = IFlyWirePullManifest(
                sessionId: UUID().uuidString,
                mintedAt: Date(),
                sourceDevice: WireSourceDevice(device),
                game: IFlyWireGameIdentity(
                    md5Hash: game.md5, displayName: game.title,
                    platform: SystemMap.wirePlatform(for: game.system, app: .iFly, slug: true) ?? "dreamcast"
                ),
                files: descriptors
            )
            return .json(try manifest.encoded())
        } catch {
            return .error(500, "pull manifest build failed: \(error)")
        }
    }

    /// iFly receivers write `relativePath` under their own base folder:
    /// `ROMs/<file>` for one file, `ROMs/<primary stem>/<path>` for a set, so
    /// GDI tracks sit next to their index and never collide across games
    /// (iFly's scanner finds an index one folder down). The primary comes
    /// first: after a pull iFly boots the first `gameFile`.
    static func layout(of game: SharedGame) -> [(String, SharedFile)] {
        guard let primary = game.primaryFile else { return [] }
        if game.files.count == 1 {
            return [("\(romsFolder)/\(primary.fileName)", primary)]
        }
        let folder = (primary.fileName as NSString).deletingPathExtension
        return game.files.map { ("\(romsFolder)/\(folder)/\($0.relativePath)", $0) }
    }

    private func file(_ request: ServerRequest) -> ServerResponse {
        guard let path = request.query[ContinuityRoutes.pathQueryItem], !path.isEmpty else {
            return .error(400, "missing ?path=")
        }
        guard let granted = allowlist[path] else { return .error(404, "not part of a granted pull") }
        guard FileManager.default.fileExists(atPath: granted.url.path) else { return .error(404, "file unavailable") }
        return .file(granted.url, size: granted.size, rangeHeader: request.header("Range"))
    }
}
