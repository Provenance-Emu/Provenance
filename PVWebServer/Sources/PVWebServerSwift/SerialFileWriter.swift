//
//  SerialFileWriter.swift
//  PVWebServer
//
//  Per-file serial write queue: socket reads can continue while flash writes run async.
//

import Foundation
import NIOCore

/// Writes one destination file on a dedicated serial queue so network I/O is not blocked by flash writes.
///
/// `@unchecked Sendable`: `FileHandle` and counters are confined to `queue`; callers await `append`/`finalize`.
final class SerialFileWriter: @unchecked Sendable {

    enum WriterError: LocalizedError {
        case alreadyFinalized
        case notOpen

        var errorDescription: String? {
            switch self {
            case .alreadyFinalized: return "SerialFileWriter already finalized"
            case .notOpen: return "SerialFileWriter is not open"
            }
        }
    }

    private let queue: DispatchQueue
    private let destination: URL
    private let stagingURL: URL
    private var fileHandle: FileHandle?
    private var finalized = false
    private var bytesWritten: Int64 = 0

    /// Stages bytes beside the destination so readers never observe a partially written upload.
    init(destination: URL) throws {
        self.destination = destination
        let parent = destination.deletingLastPathComponent()
        stagingURL = parent.appendingPathComponent(".pv-upload-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue {
            throw CocoaError(.fileWriteFileExists)
        }
        guard FileManager.default.createFile(atPath: stagingURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            fileHandle = try FileHandle(forWritingTo: stagingURL)
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            throw error
        }
        queue = DispatchQueue(
            label: "com.provenance.webserver.serialwriter.\(destination.path.hashValue)",
            qos: .utility
        )
    }

    deinit {
        try? fileHandle?.close()
        try? FileManager.default.removeItem(at: stagingURL)
    }

    /// Total bytes written after the last completed `append`.
    var totalBytesWritten: Int64 {
        queue.sync { bytesWritten }
    }

    /// Schedules a write on the serial queue and waits until it completes.
    func append(_ data: Data) async {
        guard !data.isEmpty else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [self] in
                guard !finalized, let handle = fileHandle else {
                    continuation.resume()
                    return
                }
                handle.write(data)
                bytesWritten += Int64(data.count)
                continuation.resume()
            }
        }
    }

    /// Appends readable bytes from a NIO `ByteBuffer`.
    func append(_ buffer: ByteBuffer) async {
        guard buffer.readableBytes > 0 else { return }
        let data = buffer.withUnsafeReadableBytes { ptr -> Data in
            Data(ptr)
        }
        await append(data)
    }

    /// Closes and atomically publishes the upload, then reports its total byte count.
    func finalize(completion: @escaping (Result<Int64, Error>) -> Void) {
        queue.async { [self] in
            do {
                let total = try closeOnQueue()
                completion(.success(total))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Async wrapper around `finalize(completion:)`.
    func finalize() async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            finalize { result in
                continuation.resume(with: result)
            }
        }
    }

    private func closeOnQueue() throws -> Int64 {
        if finalized {
            throw WriterError.alreadyFinalized
        }
        finalized = true
        defer {
            fileHandle = nil
            try? FileManager.default.removeItem(at: stagingURL)
        }
        guard let handle = fileHandle else {
            throw WriterError.notOpen
        }
        try handle.close()
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: stagingURL)
        } else {
            try FileManager.default.moveItem(at: stagingURL, to: destination)
        }
        return bytesWritten
    }
}
