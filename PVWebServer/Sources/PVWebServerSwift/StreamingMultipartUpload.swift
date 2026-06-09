//
//  StreamingMultipartUpload.swift
//  PVWebServer
//
//  Streams a single-file multipart/form-data POST body to disk without buffering the entire payload.
//

import Foundation
import Hummingbird
import NIOCore

/// Result of a successful streaming multipart upload (one `files[]` part).
struct StreamingMultipartUploadResult: Sendable {
    let destination: URL
    let sanitizedFilename: String
    let bytesWritten: Int64
}

/// Incrementally parses one multipart part and streams its body to disk.
enum StreamingMultipartUpload {

    enum UploadError: LocalizedError {
        case unsupportedMediaType
        case invalidMultipart
        case pathForbidden
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .unsupportedMediaType: return "Missing or invalid multipart boundary"
            case .invalidMultipart: return "Could not parse multipart body"
            case .pathForbidden: return "Upload path escapes root"
            case .writeFailed(let error): return "Upload write failed: \(error.localizedDescription)"
            }
        }
    }

    /// Streams `body` to disk when the request contains a single `files[]` part (browser upload contract).
    static func streamSingleFilePart(
        body: RequestBody,
        contentType: String,
        uploadDirectory: URL,
        resolvePath: (String, URL) -> URL?,
        onStarted: ((URL, Int) -> Void)? = nil
    ) async throws -> StreamingMultipartUploadResult {
        guard let boundary = MultipartParsing.boundary(from: contentType) else {
            throw UploadError.unsupportedMediaType
        }

        var scanner = MultipartStreamScanner(boundary: boundary)
        var headerBuffer = Data()
        var parsedHeaders = false
        var filename: String?
        var writer: SerialFileWriter?
        var destination: URL?

        for try await buffer in body {
            let chunk = buffer.withUnsafeReadableBytes { Data($0) }
            guard !chunk.isEmpty else { continue }

            if !parsedHeaders {
                headerBuffer.append(chunk)
                if let headers = MultipartParsing.parseLeadingPartHeaders(from: headerBuffer, boundary: boundary) {
                    parsedHeaders = true
                    filename = headers.filename
                    guard let name = filename else { throw UploadError.invalidMultipart }
                    let sanitized = URL(fileURLWithPath: name).lastPathComponent
                    guard !sanitized.isEmpty, !sanitized.hasPrefix(".") else { throw UploadError.invalidMultipart }
                    guard let dest = resolvePath(sanitized, uploadDirectory) else { throw UploadError.pathForbidden }
                    destination = dest
                    onStarted?(dest, 0)
                    do {
                        writer = try SerialFileWriter(destination: dest)
                    } catch {
                        throw UploadError.writeFailed(error)
                    }
                    if !headers.bodyPrefix.isEmpty {
                        await writer?.append(headers.bodyPrefix)
                    }
                    if headers.isComplete {
                        let bytes = try await writer?.finalize() ?? 0
                        return StreamingMultipartUploadResult(
                            destination: dest,
                            sanitizedFilename: sanitized,
                            bytesWritten: bytes
                        )
                    }
                } else if headerBuffer.count > 256 * 1024 {
                    throw UploadError.invalidMultipart
                }
                continue
            }

            guard let writer else { throw UploadError.invalidMultipart }
            let scan = scanner.feed(chunk)
            if !scan.writeChunk.isEmpty {
                await writer.append(scan.writeChunk)
            }
            if scan.finished {
                let bytes = try await writer.finalize()
                guard let dest = destination, let sanitized = filename.map({ URL(fileURLWithPath: $0).lastPathComponent }) else {
                    throw UploadError.invalidMultipart
                }
                return StreamingMultipartUploadResult(
                    destination: dest,
                    sanitizedFilename: sanitized,
                    bytesWritten: bytes
                )
            }
        }

        throw UploadError.invalidMultipart
    }
}

// MARK: - Multipart parsing helpers

enum MultipartParsing {

    struct LeadingPartHeaders {
        let filename: String?
        /// Bytes after the header block that belong to the file body.
        let bodyPrefix: Data
        /// True when the closing boundary was already found inside `bodyPrefix`.
        let isComplete: Bool
    }

    static func boundary(from contentType: String) -> String? {
        let parts = contentType.components(separatedBy: ";")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("boundary=") {
                var value = String(trimmed.dropFirst("boundary=".count))
                value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    static func extractFilename(from headers: String) -> String? {
        for line in headers.components(separatedBy: "\r\n") {
            guard line.lowercased().contains("content-disposition") else { continue }
            for component in line.components(separatedBy: ";") {
                let trimmed = component.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("filename=") {
                    var name = String(trimmed.dropFirst("filename=".count))
                    name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    return name.isEmpty ? nil : name
                }
            }
        }
        return nil
    }

    /// Parses the first multipart part once `\r\n\r\n` and the opening boundary are present in `data`.
    static func parseLeadingPartHeaders(from data: Data, boundary: String) -> LeadingPartHeaders? {
        guard let openBoundary = "--\(boundary)".data(using: .utf8),
              let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }
        guard data.starts(with: openBoundary) else { return nil }

        let afterOpen = openBoundary.count
        guard afterOpen + 2 <= data.count else { return nil }
        // Skip CRLF after opening boundary
        var headerStart = afterOpen
        if data[headerStart] == UInt8(ascii: "\r"), headerStart + 1 < data.count, data[headerStart + 1] == UInt8(ascii: "\n") {
            headerStart += 2
        }

        let headersData = data[headerStart..<headerEnd.lowerBound]
        let headers = String(data: headersData, encoding: .utf8) ?? ""
        let filename = extractFilename(from: headers)
        let bodyStart = headerEnd.upperBound
        let bodyPrefix = data[bodyStart...]

        var scanner = MultipartStreamScanner(boundary: boundary)
        let scan = scanner.feed(Data(bodyPrefix))
        return LeadingPartHeaders(
            filename: filename,
            bodyPrefix: scan.writeChunk,
            isComplete: scan.finished
        )
    }
}

// MARK: - Boundary scanner

/// Scans streaming body bytes, writing file payload while detecting `\r\n--boundary--` terminators.
struct MultipartStreamScanner {
    private let partialMarker: Data
    private var carry = Data()

    /// Maximum suffix bytes retained so a boundary marker split across reads is not missed.
    private var holdbackSize: Int {
        max(partialMarker.count - 1, 0)
    }

    init(boundary: String) {
        partialMarker = Data("\r\n--\(boundary)--".utf8)
    }

    struct FeedResult {
        var writeChunk: Data = Data()
        var finished = false
    }

    mutating func feed(_ chunk: Data) -> FeedResult {
        var combined = Data(carry)
        combined.append(chunk)
        carry.removeAll(keepingCapacity: true)

        // Only treat the full closing delimiter as end-of-body; `\r\n--boundary` alone
        // is a prefix of the closing marker and must not truncate early.
        if let markerStart = Self.markerStart(in: combined, marker: partialMarker) {
            let payload = markerStart > 0 ? combined.subdata(in: 0..<markerStart) : Data()
            return FeedResult(writeChunk: payload, finished: true)
        }

        let keep = min(combined.count, holdbackSize)
        guard keep < combined.count else {
            carry = combined
            return FeedResult(writeChunk: Data(), finished: false)
        }

        let emitCount = combined.count - keep
        guard emitCount > 0 else {
            carry = combined
            return FeedResult(writeChunk: Data(), finished: false)
        }

        let write = combined.subdata(in: 0..<emitCount)
        carry = combined.subdata(in: emitCount..<combined.count)
        return FeedResult(writeChunk: write, finished: false)
    }

    /// Finds the first validated occurrence of `marker` in `data`.
    private static func markerStart(in data: Data, marker: Data) -> Int? {
        guard !marker.isEmpty, data.count >= marker.count else { return nil }
        let lastStart = data.count - marker.count
        for start in 0...lastStart where data.subdata(in: start..<(start + marker.count)) == marker {
            return start
        }
        return nil
    }
}
