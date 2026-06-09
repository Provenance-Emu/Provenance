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
    private var fileHandle: FileHandle?
    private var finalized = false
    private var bytesWritten: Int64 = 0

    /// Creates/truncates `destination` and opens it for writing.
    init(destination: URL) throws {
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        fileHandle = try FileHandle(forWritingTo: destination)
        queue = DispatchQueue(
            label: "com.provenance.webserver.serialwriter.\(destination.path.hashValue)",
            qos: .utility
        )
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

    /// Closes the handle on the serial queue, then invokes `completion` with total bytes written.
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
        defer { fileHandle = nil }
        guard let handle = fileHandle else {
            throw WriterError.notOpen
        }
        try handle.close()
        return bytesWritten
    }
}
