//
//  PVLibraryDialectServer.swift
//  PVLibrarySharing
//
//  The shared v1.1 type `_pvlibrary._tcp` (spec §3.2, phase 4).
//

import Foundation
import PVSystems

/// `_pvlibrary._tcp`: iCube's route shape with iFly's consent auth and neutral
/// `pvlibrary-*` prefixes, serving every system the owner shares.
///
/// - `POST library/auth/start` / `auth/complete`: consent auth (`ConsentGate`).
/// - `POST pair/start` / `pair/complete`: code pairing (`PairingGate`); a
///   right code answers 200 `{"paired":true}`.
/// - `GET library/catalog`: `ETag`/304, `?systemIdentifier=`, `?limit=&cursor=`.
/// - `GET library/manifest?key=`: one game's files. "Ask per game" answers
///   202 while the owner decides and 403 on a refusal; the client polls.
/// - `GET library/file?key=&path=`: Range-aware, only for an approved key.
/// - `GET library/art?key=`.
///
/// Every route answers 404 while sharing is off.
public actor PVLibraryDialectServer {
    private let identity: PeerIdentity
    private let device: HostDevice
    private let library: any SharedLibraryProviding
    private let hashes: FileHashCache
    private let sharingEnabled: @Sendable () async -> Bool
    private let gate: ConsentGate
    private let pairing: PairingGate
    /// `peerId|key` whose manifest was granted: the file route's allowlist.
    private var granted: Set<String> = []

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
        gate = ConsentGate(identity: identity, domain: .pvLibrary, app: .pvLibrary, trust: trust, approver: approver)
        pairing = PairingGate(
            identity: identity, device: device, domain: .pvLibrary, app: .pvLibrary, trust: trust, approver: approver,
            paired: .encoded(PVPairedResponse())
        )
    }

    public func revokeAll() async {
        granted.removeAll()
        await gate.revokeAll()
        await pairing.reset()
    }

    public func revoke(peerId: String) async {
        granted = granted.filter { !$0.hasPrefix("\(peerId)|") }
        await gate.revoke(peerId: peerId)
    }

    public func handle(_ request: ServerRequest) async -> ServerResponse {
        guard await sharingEnabled() else { return .error(404, "library sharing unavailable") }
        switch (request.method, request.path) {
        case ("POST", ContinuityRoutes.pairStart): return await pairing.start(request)
        case ("POST", ContinuityRoutes.pairComplete): return await pairing.complete(request)
        case ("POST", ContinuityRoutes.libraryAuthStart): return await gate.start(request)
        case ("POST", ContinuityRoutes.libraryAuthComplete): return await gate.complete(request)
        default: break
        }
        guard let peerId = await gate.peer(forAuthorization: request.header("Authorization")) else {
            return .error(401, "invalid or missing library token")
        }
        switch (request.method, request.path) {
        case ("GET", ContinuityRoutes.iCubeLibraryCatalog): return await catalog(request)
        case ("GET", ContinuityRoutes.libraryArt): return await art(request)
        case ("GET", ContinuityRoutes.iCubeLibraryManifest): return await manifest(request, peerId: peerId)
        case ("GET", ContinuityRoutes.libraryFile): return await file(request, peerId: peerId)
        default: return .error(404, "not found")
        }
    }

    // MARK: - Catalogue

    /// `md5:<md5>`, or the game id when there is no MD5.
    static func key(for game: SharedGame) -> String {
        game.md5.map { "md5:\($0)" } ?? "id:\(game.id)"
    }

    private func entries() async -> [(game: SharedGame, entry: PVWireCatalog.Entry)] {
        await library.sharedGames()
            .filter { !$0.files.isEmpty }
            .map { game in
                (game, PVWireCatalog.Entry(
                    key: Self.key(for: game),
                    game: PVWireGameIdentity(
                        gameID: game.system == .GameCube || game.system == .Wii ? ICubeDialectServer.discID(game.serial) : nil,
                        md5: game.md5, serial: game.serial, displayName: game.title, platform: game.system.rawValue
                    ),
                    sizeBytes: game.sizeBytes, hasArtwork: game.hasArtwork, systemIdentifier: game.system.rawValue
                ))
            }
            .sorted { $0.entry.key < $1.entry.key }
    }

    private func catalog(_ request: ServerRequest) async -> ServerResponse {
        let query = CatalogueQuery(query: request.query)
        let all = await entries().filter { query.admits($0.game.system) }.map(\.entry)
        let version = PVWireCatalog.version(of: all)
        if query.cursor == nil, request.header("If-None-Match") == version {
            return ServerResponse(status: 304)
        }
        do {
            let page = try query.page(all, version: version)
            let catalog = PVWireCatalog(sourceDevice: WireSourceDevice(device), entries: page.items, nextCursor: page.nextCursor)
            return .json(try iCubeEncoded(catalog), headers: ["ETag": version])
        } catch CatalogueQuery.PageError.staleCursor {
            return .error(410, "the catalogue changed; start from the first page")
        } catch {
            return .error(500, "catalog build failed")
        }
    }

    private func art(_ request: ServerRequest) async -> ServerResponse {
        guard let key = request.query[ContinuityRoutes.keyQueryItem], !key.isEmpty else { return .error(400, "missing ?key=") }
        guard let game = await entries().first(where: { $0.entry.key == key })?.game, game.hasArtwork,
              let data = await library.artwork(forGameId: game.id) else {
            return .error(404, "no artwork for that entry")
        }
        return ServerResponse(status: 200, headers: ["Content-Type": "application/octet-stream"], body: .data(data))
    }

    // MARK: - Manifest and files

    /// Neutral layout: `<file>` alone, `<primary stem>/<path>` for a set,
    /// primary first.
    static func layout(of game: SharedGame) -> [(String, SharedFile)] {
        guard let primary = game.primaryFile else { return [] }
        if game.files.count == 1 { return [(primary.fileName, primary)] }
        let folder = (primary.fileName as NSString).deletingPathExtension
        return game.files.map { ("\(folder)/\($0.relativePath)", $0) }
    }

    private func manifest(_ request: ServerRequest, peerId: String) async -> ServerResponse {
        guard let key = request.query[ContinuityRoutes.keyQueryItem], !key.isEmpty else { return .error(400, "missing ?key=") }
        guard let found = await entries().first(where: { $0.entry.key == key }) else { return .error(404, "no such game") }
        if let interim = await gate.pullApproval(peerId: peerId, gameId: key, gameTitle: found.game.title) {
            return interim
        }
        do {
            var files: [WireFileDescriptor] = []
            for (path, file) in Self.layout(of: found.game) {
                let sha = try await hashes.sha256(of: file.url)
                files.append(WireFileDescriptor(kind: RemoteFile.gameFileKind, relativePath: path, sha256: sha, size: file.size, required: true))
            }
            granted.insert("\(peerId)|\(key)")
            let manifest = PVWireManifest(
                sessionId: key, mintedAt: Date(), sourceDevice: WireSourceDevice(device), game: found.entry.game, files: files
            )
            return .json(try iCubeEncoded(manifest))
        } catch {
            return .error(500, "manifest build failed: \(error)")
        }
    }

    private func file(_ request: ServerRequest, peerId: String) async -> ServerResponse {
        guard let key = request.query[ContinuityRoutes.keyQueryItem], !key.isEmpty else { return .error(400, "missing ?key=") }
        guard let path = request.query[ContinuityRoutes.pathQueryItem], !path.isEmpty else { return .error(400, "missing ?path=") }
        guard granted.contains("\(peerId)|\(key)") else { return .error(404, "not part of a granted pull") }
        guard let game = await entries().first(where: { $0.entry.key == key })?.game,
              let file = Self.layout(of: game).first(where: { $0.0 == path })?.1 else {
            return .error(404, "not part of that game")
        }
        guard FileManager.default.fileExists(atPath: file.url.path) else { return .error(404, "file unavailable") }
        return .file(file.url, size: file.size, rangeHeader: request.header("Range"))
    }
}
