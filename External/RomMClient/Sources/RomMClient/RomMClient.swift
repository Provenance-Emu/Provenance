import Foundation

/// Read-only access to a RomM instance. The app owns credentials and import policy.
public struct RomMClient: Sendable {
    public let address: RomMAddress
    private let authorization: String?
    private let transport: any RomMTransport

    public init(address: RomMAddress, credential: RomMCredential, allowHTTP: Bool = false) throws {
        try self.init(address: address, credential: credential, allowHTTP: allowHTTP, transport: RomMURLSession())
    }

    init(address: RomMAddress, credential: RomMCredential, allowHTTP: Bool = false, transport: any RomMTransport) throws {
        let authorization = try credential.authorization()
        guard authorization == nil || address.isHTTPS || allowHTTP else { throw RomMError.insecureConnection }
        self.address = address
        self.authorization = authorization
        self.transport = transport
    }

    public func platforms() async throws -> [RomMPlatform] {
        try await read(["platforms"])
    }

    public func games(platformID: Int, search: String = "", offset: Int = 0, limit: Int = 50) async throws -> RomMPage {
        guard platformID > 0, offset >= 0, (1...100).contains(limit) else { throw RomMError.invalidContent }
        let query = [
            URLQueryItem(name: "platform_ids", value: String(platformID)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "with_char_index", value: "false"),
            URLQueryItem(name: "with_filter_values", value: "false"),
            URLQueryItem(name: "with_rom_id_index", value: "false")
        ] + (search.isEmpty ? [] : [URLQueryItem(name: "search_term", value: search)])
        let page: RomMPage = try await read(["roms"], query: query)
        guard page.offset == offset, page.limit > 0, page.total >= 0, page.items.count <= limit,
              page.items.allSatisfy({ $0.platformId == platformID })
        else { throw RomMError.invalidResponse }
        return page
    }

    /// Stages every game file, keeping paths relative to its RomM game directory.
    /// Each request selects a single file by ID so the original archive and disc
    /// members arrive unchanged, including repeated basenames in separate folders.
    public func download(_ game: RomMGame) async throws -> RomMDownload {
        guard game.id > 0, game.isDownloadable else { throw RomMError.unavailable }
        let detail: Detail = try await read(["roms", String(game.id)])
        guard detail.id == game.id else { throw RomMError.invalidResponse }
        let files = try detail.downloadFiles()
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("RomM-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: false)
        do {
            var results: [URL] = []
            for file in files {
                try Task.checkCancellation()
                let request = try request(
                    ["roms", String(game.id), "content", file.name],
                    query: [URLQueryItem(name: "file_ids", value: String(file.id))]
                )
                let (temporary, response) = try await transport.download(for: request)
                defer { try? manager.removeItem(at: temporary) }
                try Self.validate(response)
                let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init)
                guard size == file.size else { throw RomMError.invalidContent }
                let destination = directory.appendingPathComponent(file.path)
                try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try manager.moveItem(at: temporary, to: destination)
                results.append(destination)
            }
            try Task.checkCancellation()
            return RomMDownload(directory: directory, files: results)
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    private func read<T: Decodable>(_ route: [String], query: [URLQueryItem] = []) async throws -> T {
        let (data, response) = try await transport.data(for: request(route, query: query))
        try Self.validate(response)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch is DecodingError {
            throw RomMError.invalidResponse
        }
    }

    private func request(_ route: [String], query: [URLQueryItem]) throws -> URLRequest {
        var request = URLRequest(url: try address.endpoint(route, query: query))
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        return request
    }

    private static func validate(_ response: URLResponse) throws {
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw RomMError.invalidResponse }
        switch status {
        case 200: return
        case 401, 403: throw RomMError.accessDenied
        case 404: throw RomMError.unavailable
        default: throw RomMError.status(status)
        }
    }
}

private struct Detail: Decodable {
    struct File: Decodable {
        let id: Int
        let fileName: String
        let filePath: String
        let fileSizeBytes: Int64
        let category: String?
    }

    let id: Int
    let fsName: String
    let fsPath: String
    let files: [File]

    func downloadFiles() throws -> [(id: Int, name: String, path: String, size: Int64)] {
        let root = fsPath + "/" + fsName
        let candidates = files.filter { $0.category == nil || $0.category == "game" }
        guard RomMPath.isComponent(fsName), !candidates.isEmpty else { throw RomMError.invalidContent }
        var ids = Set<Int>()
        var paths = Set<String>()
        var directories = Set<String>()
        return try candidates.map { file in
            guard file.id > 0, ids.insert(file.id).inserted, file.fileSizeBytes > 0,
                  RomMPath.isComponent(file.fileName)
            else { throw RomMError.invalidContent }
            let subdirectory: String
            if file.filePath == root || (file.filePath == fsPath && file.fileName == fsName) {
                subdirectory = ""
            } else if file.filePath.hasPrefix(root + "/") {
                subdirectory = String(file.filePath.dropFirst(root.count + 1))
                guard !subdirectory.isEmpty else { throw RomMError.invalidContent }
            } else {
                throw RomMError.invalidContent
            }
            let path = subdirectory.isEmpty ? file.fileName : subdirectory + "/" + file.fileName
            let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard components.allSatisfy(RomMPath.isComponent) else { throw RomMError.invalidContent }
            let normalized = components.map { $0.precomposedStringWithCanonicalMapping.lowercased() }
            let key = normalized.joined(separator: "/")
            guard !directories.contains(key), paths.insert(key).inserted else { throw RomMError.invalidContent }
            for end in 1..<normalized.count {
                let parent = normalized.prefix(end).joined(separator: "/")
                guard !paths.contains(parent) else { throw RomMError.invalidContent }
                directories.insert(parent)
            }
            return (file.id, file.fileName, path, file.fileSizeBytes)
        }
    }
}

protocol RomMTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func download(for request: URLRequest) async throws -> (URL, URLResponse)
}

private final class RomMURLSession: RomMTransport {
    private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(
            _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }()

    deinit { session.invalidateAndCancel() }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        try await session.download(for: request)
    }
}
