import Foundation
import RomMClient
import XCTest
@testable import PVLibrarySharing

final class RomMRecoveryTests: XCTestCase {
    func testSearchAndRestoreUnderTheOriginalFilename() async throws {
        let transport = RecoveryRomMTransport()
        let client = try RomMClient(address: RomMAddress("https://romm.example"), credential: .none, transport: transport)
        let source = RomMSource(client: client, systemFor: { $0.slug == "dc" ? .Dreamcast : nil })
        let file = MissingGameFile(name: "My Copy.chd", size: 3, isPrimary: true)
        let query = MissingGameQuery(md5: "", system: .Dreamcast, title: "Test Game", files: [file], isSingleFileImage: true)

        let candidate = try await source.recoveryCandidate(for: query)
        let game = try XCTUnwrap(candidate)
        XCTAssertEqual(game.fileName, "Test Game.chd")
        let searchTerms = await transport.searchTerms
        XCTAssertEqual(searchTerms, ["Test Game"])
        let pulled = try await source.recoveryPull(game, for: query)
        defer { try? FileManager.default.removeItem(at: pulled.folder) }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = RestoreTarget(file: file, url: directory.appendingPathComponent(file.name))
        let restored = try MissingGameRestorer.restore(
            pulled, to: [target], kind: .standIn, staging: LibraryStaging(root: directory)
        )
        XCTAssertEqual(restored.restored, [target.url])
        XCTAssertEqual(try Data(contentsOf: target.url), Data([1, 2, 3]))
    }
}

private actor RecoveryRomMTransport: RomMTransport {
    private(set) var searchTerms: [String] = []

    func data(for request: URLRequest) throws -> (Data, URLResponse) {
        let url = try XCTUnwrap(request.url)
        let json: String
        switch url.path {
        case "/api/platforms":
            json = #"[{"id":7,"slug":"dc","name":"Dreamcast","rom_count":1}]"#
        case "/api/roms":
            let term = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "search_term" }?.value
            searchTerms.append(try XCTUnwrap(term))
            json = """
            {"items":[{"id":4,"name":"Test Game","fs_name":"Test Game.chd","platform_id":7,
            "platform_slug":"dc","fs_size_bytes":3}],"limit":50,"total":1,"offset":0}
            """
        case "/api/roms/4":
            json = """
            {"id":4,"fs_name":"Test Game.chd","fs_path":"roms/dc",
            "files":[{"id":1,"file_name":"Test Game.chd","file_path":"roms/dc","file_size_bytes":3,"category":"game"}]}
            """
        default:
            throw URLError(.badURL)
        }
        return (Data(json.utf8), try response(for: url))
    }

    func download(for request: URLRequest) throws -> (URL, URLResponse) {
        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(url.path, "/api/roms/4/content/Test Game.chd")
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1, 2, 3]).write(to: temporary)
        return (temporary, try response(for: url))
    }

    private func response(for url: URL) throws -> URLResponse {
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
    }
}
