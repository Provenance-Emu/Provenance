//
//  ServerTestSupport.swift
//  PVLibrarySharingTests
//
//  A shared library on disk, a scripted owner, and a transport that hands
//  client requests straight to a dialect server.
//

import Foundation
import PVSystems
import XCTest
@testable import PVLibrarySharing

/// Calls a server handler in-process, as the listener would.
struct InProcessTransport: LibraryHTTPTransport {
    let handler: ServerRequestHandler

    func send(_ request: LibraryHTTPRequest) async throws -> LibraryHTTPResponse {
        let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
        var query: [String: String] = [:]
        for item in components?.queryItems ?? [] { query[item.name] = item.value ?? "" }
        let response = await handler(ServerRequest(
            method: request.method, path: request.url.path, query: query, headers: request.headers, body: request.body
        ))
        let body: Data
        switch response.body {
        case .data(let data):
            body = data
        case let .file(url, offset, length):
            let all = try Data(contentsOf: url)
            let end = length.map { Int(offset + $0) } ?? all.count
            body = all.subdata(in: Int(offset)..<end)
        }
        return LibraryHTTPResponse(status: response.status, headers: response.headers, body: body)
    }
}

/// The owner's answers, scripted; records what was asked.
final class ScriptedOwner: LibraryHostApproving, @unchecked Sendable {
    private let lock = NSLock()
    var browse: BrowseConsent = .shareEverything
    var pull: PullConsent = .allowOnce
    var pairing = true
    private(set) var shownCodes: [String] = []
    private(set) var pullPrompts: [String] = []

    var lastCode: String? { lock.withLock { shownCodes.last } }

    func approveBrowse(peerName: String, app: PeerApp) async -> BrowseConsent {
        lock.withLock { browse }
    }

    func approvePairing(peerName: String, code: String) async -> Bool {
        lock.withLock {
            shownCodes.append(code)
            return pairing
        }
    }

    func approvePull(peerName: String, gameTitle: String) async -> PullConsent {
        lock.withLock {
            pullPrompts.append(gameTitle)
            return pull
        }
    }
}

/// Games on disk: a Dreamcast GDI set, a single-file Dreamcast CHD, a
/// GameCube ISO and an NES ROM (which no peer dialect may list).
final class DiskLibrary: SharedLibraryProviding, @unchecked Sendable {
    let root: URL
    private(set) var games: [SharedGame] = []
    let art = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])

    init(root: URL) throws {
        self.root = root
        func write(_ relative: String, _ data: Data) throws -> SharedFile {
            let url = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            return SharedFile(url: url, relativePath: (relative as NSString).lastPathComponent, size: Int64(data.count))
        }
        let gdi = try write("Dreamcast/Ikaruga/Ikaruga.gdi", Data("2\n1 0 4 2352 track01.bin 0\n2 600 0 2352 track02.bin 0\n".utf8))
        let track1 = try write("Dreamcast/Ikaruga/track01.bin", Data((0..<70_000).map { UInt8($0 % 253) }))
        let track2 = try write("Dreamcast/Ikaruga/track02.bin", Data((0..<9_000).map { UInt8($0 % 13) }))
        let chd = try write("Dreamcast/Rez.chd", Data((0..<30_000).map { UInt8($0 % 7) }))
        let iso = try write("GameCube/Sunshine.iso", Data((0..<50_000).map { UInt8($0 % 101) }))
        let nes = try write("NES/Mario.nes", Data(repeating: 0x4E, count: 4_096))
        games = [
            SharedGame(id: "IKARUGA", title: "Ikaruga", system: .Dreamcast, md5: "AAAA0000AAAA0000AAAA0000AAAA0000",
                       files: [gdi, track1, track2], hasArtwork: true),
            SharedGame(id: "REZ", title: "Rez", system: .Dreamcast, md5: "BBBB1111BBBB1111BBBB1111BBBB1111",
                       files: [chd], hasArtwork: false),
            SharedGame(id: "SUNSHINE", title: "Super Mario Sunshine", system: .GameCube, md5: "CCCC2222CCCC2222CCCC2222CCCC2222",
                       serial: "gmse01", files: [iso], hasArtwork: true),
            SharedGame(id: "MARIO", title: "Super Mario Bros.", system: .NES, md5: "DDDD3333DDDD3333DDDD3333DDDD3333",
                       files: [nes], hasArtwork: false)
        ]
    }

    func sharedGames() async -> [SharedGame] { games }

    func artwork(forGameId id: String) async -> Data? {
        games.first { $0.id == id && $0.hasArtwork } != nil ? art : nil
    }

    func data(of gameId: String) throws -> [Data] {
        try games.first { $0.id == gameId }?.files.map { try Data(contentsOf: $0.url) } ?? []
    }
}

/// A host, a library and a scripted owner, wired for one dialect.
struct ServerFixture {
    let root: URL
    let library: DiskLibrary
    let owner = ScriptedOwner()
    let trust = FileHostTrustStore(fileURL: nil)
    let hostIdentity = PeerIdentity(id: "provenance-host", name: "Provenance on iPad")
    let device = HostDevice(name: "Joe's iPad", platform: "iOS", appVersion: "3.4.0")
    let sharing = SharingFlag()

    init() throws {
        root = try makeTemporaryFolder()
        library = try DiskLibrary(root: root.appendingPathComponent("library"))
        sharing.value = true
    }

    func iFlyServer() -> IFlyDialectServer {
        let flag = sharing
        return IFlyDialectServer(
            identity: hostIdentity, device: device, library: library, trust: trust, approver: owner,
            hashes: FileHashCache(storeURL: root.appendingPathComponent("hashes.json")), sharingEnabled: { flag.value }
        )
    }

    func iCubeServer() -> ICubeDialectServer {
        let flag = sharing
        return ICubeDialectServer(
            identity: hostIdentity, device: device, library: library, trust: trust, approver: owner,
            hashes: FileHashCache(), sharingEnabled: { flag.value }
        )
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// iFly's decoders, field for field: what iFly requires to be present.
/// (`ContinuityKit/Model/ContinuityManifest.swift`, `FileDescriptor.swift`,
/// `ContinuityLibraryManifest.swift`, `GameIdentity.swift`, `SourceDevice.swift`.)
enum IFlyStrict {
    struct FileDescriptor: Decodable {
        var kind: String
        var relativePath: String
        var sha256: String
        var size: Int64
        var modifiedAt: Date?
        var required: Bool
    }

    struct SourceDevice: Decodable {
        var name: String
        var platform: String
        var appVersion: String
    }

    struct GameIdentity: Decodable {
        var flycastGameId: String?
        var md5Hash: String?
        var serial: String?
        var displayName: String
        var platform: String
    }

    struct OptionalExtra: Decodable {
        var kind: String
        var label: String
        var totalSize: Int64
        var fileCount: Int
    }

    struct Manifest: Decodable {
        var version: Int
        var sessionId: String
        var mintedAt: Date
        var sourceDevice: SourceDevice
        var game: GameIdentity
        var files: [FileDescriptor]
        var bios: [FileDescriptor]
        var optionalExtras: [OptionalExtra]
    }

    struct LibraryManifest: Decodable {
        struct Game: Decodable {
            var title: String
            var platform: String
            var md5: String?
            var sizeBytes: Int64
            var artKey: String?
            var saveStateCount: Int
            var vmuFileCount: Int?
        }

        var version: Int
        var peerId: String
        var deviceName: String
        var games: [Game]
        var catalogVersion: String?
    }

    static func manifest(_ data: Data) throws -> Manifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Manifest.self, from: data)
    }
}

/// iCube's decoders (`PVContinuity/Model/`).
enum ICubeStrict {
    struct GameIdentity: Decodable {
        var gameID: String?
        var md5: String?
        var crc32: String?
        var displayName: String
        var platform: String
        var discNumber: Int?
        var revision: Int?
    }

    struct SourceDevice: Decodable {
        var name: String
        var platform: String
        var appVersion: String
    }

    struct FileDescriptor: Decodable {
        var kind: String
        var relativePath: String
        var sha256: String
        var size: Int64
        var modifiedAt: Date?
        var required: Bool
    }

    struct Manifest: Decodable {
        var version: Int
        var sessionId: String
        var mintedAt: Date
        var sourceDevice: SourceDevice
        var game: GameIdentity
        var files: [FileDescriptor]
    }

    struct Catalog: Decodable {
        struct Entry: Decodable {
            var key: String
            var game: GameIdentity
            var sizeBytes: Int64
            var hasArtwork: Bool
        }

        var version: Int
        var sourceDevice: SourceDevice
        var entries: [Entry]
    }

    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
