import CryptoKit
import Foundation
import PVLogging

// MARK: - Streaming Event Type

/// Events emitted during a streaming MD5 calculation.
public enum MD5HashingEvent: Sendable {
    /// Intermediate progress update while reading the file.
    case progress(bytesProcessed: Int64, totalBytes: Int64)
    /// Final event when hashing is complete, carrying the uppercase hex MD5 string.
    case completed(md5: String)
}

// MARK: - Async API

/// Calculates the MD5 hash of a file using Swift structured concurrency.
///
/// **Note:** Unlike the Combine-based synchronous API, this method does not
/// automatically retry transient file-access errors (e.g., iCloud/file-provider
/// issues). Callers requiring retry logic should implement it at a higher level.
///
/// - Parameters:
///   - fileURL: The URL of the file to hash.
///   - offset: Byte offset to start reading from. Defaults to `0`.
/// - Returns: Uppercase hex MD5 string (consistent with synchronous API).
/// - Throws: Any `FileHandle` or file-system error encountered during reading.
public func calculateMD5Async(of fileURL: URL, startingAt offset: UInt64 = 0) async throws -> String {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
        DispatchQueue.global(qos: .utility).async {
            do {
                let hash = try _computeMD5(of: fileURL, startingAt: offset)
                continuation.resume(returning: hash)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Streaming API

/// Streams MD5 hashing progress and delivers the final hash via `AsyncThrowingStream`.
///
/// The stream emits `.progress` events as each chunk is read, then a single
/// `.completed` event carrying the uppercase hex MD5 string (consistent with
/// synchronous API), followed by stream termination. If the task is cancelled
/// the stream finishes with a `CancellationError`.
///
/// **Note:** Unlike the Combine-based synchronous API, this method does not
/// automatically retry transient file-access errors. Callers requiring retry
/// logic should implement it at a higher level.
///
/// - Parameters:
///   - fileURL: The URL of the file to hash.
///   - offset: Byte offset to start reading from. Defaults to `0`.
/// - Returns: An `AsyncThrowingStream` of `MD5HashingEvent`.
public func calculateMD5Stream(
    of fileURL: URL,
    startingAt offset: UInt64 = 0
) -> AsyncThrowingStream<MD5HashingEvent, Error> {
    AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        let task = Task.detached(priority: .utility) {
            do {
                let fileHandle = try FileHandle(forReadingFrom: fileURL)
                defer { try? fileHandle.close() }

                if offset > 0 {
                    try fileHandle.seek(toOffset: offset)
                }

                // Determine total bytes for progress reporting.
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = resourceValues.fileSize.map { Int64($0) } ?? 0
                let fileSizeUInt = fileSize > 0 ? UInt64(fileSize) : 0
                let remainingBytesUInt = offset >= fileSizeUInt ? 0 : (fileSizeUInt - offset)
                let totalBytes = remainingBytesUInt > UInt64(Int64.max) ? Int64.max : Int64(remainingBytesUInt)

                var hasher = Insecure.MD5()
                var bytesProcessed: Int64 = 0
                let bufferSize = 1024 * 1024 // 1 MB per chunk

                while !Task.isCancelled {
                    guard let chunk = try fileHandle.read(upToCount: bufferSize), !chunk.isEmpty else {
                        break
                    }

                    hasher.update(data: chunk)
                    bytesProcessed += Int64(chunk.count)

                    continuation.yield(.progress(
                        bytesProcessed: bytesProcessed,
                        totalBytes: totalBytes
                    ))
                }

                if Task.isCancelled {
                    continuation.finish(throwing: CancellationError())
                    return
                }

                let result = hasher.finalize()
                let hashString = result.map { String(format: "%02x", $0) }.joined().uppercased()
                continuation.yield(.completed(md5: hashString))
                continuation.finish()
            } catch {
                VLOG("calculateMD5Stream failed for \(fileURL.lastPathComponent): \(error.localizedDescription)")
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }
    }
}

// MARK: - Internal Helper

/// Core blocking MD5 computation used by `calculateMD5Async`.
///
/// This helper performs synchronous file I/O on the calling thread and is
/// intended to be dispatched to a background queue by its callers.
func _computeMD5(of fileURL: URL, startingAt offset: UInt64) throws -> String {
    let fileHandle = try FileHandle(forReadingFrom: fileURL)
    defer { try? fileHandle.close() }

    if offset > 0 {
        try fileHandle.seek(toOffset: offset)
    }

    var hasher = Insecure.MD5()
    let bufferSize = 1024 * 1024 // 1 MB per chunk

    while true {
        guard let chunk = try fileHandle.read(upToCount: bufferSize), !chunk.isEmpty else {
            break
        }
        hasher.update(data: chunk)
    }

    let result = hasher.finalize()
    return result.map { String(format: "%02x", $0) }.joined().uppercased()
}
