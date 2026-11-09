//
//  PVHostedWebServer+Routes.swift
//  PVWebServerHost
//
//  What the file-manager page calls. `POST /upload` and WebDAV are the engine's own. Routes
//  match exact paths, so each takes its subject from the query or the JSON body.
//

import Foundation
import PVWebServer

// MARK: - Files

extension PVHostedWebServer {

    func registerFileRoutes() {
        route("GET", "/") { server, _ in
            let root = server.browseRoot.path
            let uploads = server.uploadDirectory.path
                .replacingOccurrences(of: root, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return WebRouteResponse(
                status: 200,
                contentType: "text/html; charset=utf-8",
                body: .data(Data(FileManagerPage.html(defaultUploadPath: uploads).utf8))
            )
        }
        route("GET", "/files") { server, request in server.listFiles(request) }
        route("GET", "/download") { server, request in server.download(request) }
        route("POST", "/folders") { server, request in server.createFolder(request) }
        route("PATCH", "/files") { server, request in server.moveFile(request) }
        route("DELETE", "/files") { server, request in server.deleteFile(request) }
        route("POST", "/files/batch-delete") { server, request in server.deleteFiles(request) }
    }

    /// Adds a route that holds the server weakly: the engine owning the handler is ours.
    func route(_ method: String, _ path: String, _ handler: @escaping @Sendable (PVHostedWebServer, WebRouteRequest) async -> WebRouteResponse) {
        engine.addAsyncHandler(forMethod: method, path: path) { [weak self] request in
            guard let self else { return WebRouteResponse(status: 503) }
            return await handler(self, request)
        }
    }

    private func listFiles(_ request: WebRouteRequest) -> WebRouteResponse {
        let rawPath = request.query["path"] ?? ""
        guard let target = resolved(rawPath) else { return .error(status: 403, message: "Path escapes root") }
        guard isDirectory(target) else { return .error(status: 404, message: "Not a directory") }

        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
        let listing = (try? FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: keys)) ?? []
        let dates = ISO8601DateFormatter()
        let items = listing
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .map { url -> (name: String, isDirectory: Bool, size: Int, modified: String) in
                let values = try? url.resourceValues(forKeys: Set(keys))
                let directory = values?.isDirectory ?? false
                return (
                    url.lastPathComponent,
                    directory,
                    directory ? 0 : (values?.fileSize ?? 0),
                    values?.contentModificationDate.map(dates.string(from:)) ?? ""
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map { ["name": $0.name, "size": $0.size, "modified": $0.modified, "isDirectory": $0.isDirectory] as [String: Any] }
        return Self.json(["path": rawPath, "items": items])
    }

    private func download(_ request: WebRouteRequest) -> WebRouteResponse {
        guard let rawPath = request.query["path"], !rawPath.isEmpty,
              let target = resolved(rawPath),
              FileManager.default.fileExists(atPath: target.path),
              !isDirectory(target) else {
            return WebRouteResponse(status: 404)
        }
        let filename = target.lastPathComponent.replacingOccurrences(of: "\"", with: "")
        return WebRouteResponse(
            status: 200,
            contentType: "application/octet-stream",
            headers: ["Content-Disposition": "attachment; filename=\"\(filename)\""],
            body: .file(url: target, offset: 0, length: nil)
        )
    }

    private func createFolder(_ request: WebRouteRequest) -> WebRouteResponse {
        let json = Self.jsonObject(request.body)
        guard let name = (json["name"] as? String)?.trimmingCharacters(in: .whitespaces),
              !name.isEmpty, !name.contains("/"), !name.hasPrefix(".") else {
            return .error(status: 400, message: "Invalid folder name")
        }
        let parentPath = (json["path"] as? String) ?? ""
        guard let parent = resolved(parentPath),
              let target = resolved((parentPath as NSString).appendingPathComponent(name)) else {
            return .error(status: 403, message: "Path escapes root")
        }
        guard isDirectory(parent) else { return .error(status: 404, message: "Parent not found") }
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        } catch {
            return .error(status: 409, message: "Already exists or unwritable")
        }
        NotificationCenter.default.post(name: .pvWebServerFolderCreated, object: self, userInfo: ["filePath": target.path])
        return WebRouteResponse(status: 201)
    }

    private func moveFile(_ request: WebRouteRequest) -> WebRouteResponse {
        let json = Self.jsonObject(request.body)
        guard let from = json["from"] as? String, !from.isEmpty,
              let to = json["to"] as? String, !to.isEmpty,
              let source = resolved(from),
              let destination = resolved(to) else {
            return .error(status: 400, message: "Invalid move payload")
        }
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            return .error(status: 409, message: "Move failed")
        }
        NotificationCenter.default.post(
            name: .pvWebServerFileMoved,
            object: self,
            userInfo: ["fromPath": source.path, "toPath": destination.path]
        )
        return WebRouteResponse(status: 204)
    }

    private func deleteFile(_ request: WebRouteRequest) -> WebRouteResponse {
        guard let target = deletable(request.query["path"] ?? "") else {
            return .error(status: 403, message: "Refusing to delete root")
        }
        do {
            try remove(target)
        } catch {
            return .error(status: 404, message: "Delete failed")
        }
        return WebRouteResponse(status: 204)
    }

    private func deleteFiles(_ request: WebRouteRequest) -> WebRouteResponse {
        guard let paths = Self.jsonObject(request.body)["paths"] as? [String], !paths.isEmpty else {
            return .error(status: 400, message: "Missing paths array")
        }
        var deleted = 0
        var failed: [[String: String]] = []
        for path in paths {
            guard let target = deletable(path) else {
                failed.append(["path": path, "error": "forbidden"])
                continue
            }
            do {
                try remove(target)
                deleted += 1
            } catch {
                failed.append(["path": path, "error": error.localizedDescription])
            }
        }
        return Self.json(["deleted": deleted, "failed": failed])
    }

    private func remove(_ target: URL) throws {
        try FileManager.default.removeItem(at: target)
        NotificationCenter.default.post(name: .pvWebServerFileDeleted, object: self, userInfo: ["filePath": target.path])
    }

    private func deletable(_ rawPath: String) -> URL? {
        guard !rawPath.isEmpty, let target = resolved(rawPath),
              target.path != browseRoot.standardized.path else { return nil }
        return target
    }

    private func resolved(_ rawPath: String) -> URL? {
        guard case .ok(let url) = WebServerPathSafety.resolve(rawPath, within: browseRoot) else { return nil }
        return url
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func jsonObject(_ body: Data?) -> [String: Any] {
        guard let body, let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return [:] }
        return object
    }

    static func json(_ object: Any) -> WebRouteResponse {
        .json((try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8))
    }
}
