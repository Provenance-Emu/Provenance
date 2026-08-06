#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
#if canImport(Checksum)
import Checksum
#endif
import Foundation
import PVLogging
#if canImport(Combine)
import Combine
#endif

/// Notification names for file access errors and coordination
public extension Notification.Name {
    static let fileAccessError = Notification.Name("fileAccessError")
    static let checkFileRecoveryStatus = Notification.Name("checkFileRecoveryStatus")
    static let fileRecoveryStatusResponse = Notification.Name("fileRecoveryStatusResponse")
}

extension FileManager: MD5Provider {
    public func md5ForFile(at url: URL, fromOffset offset: UInt = 0) -> String? {
        #if LEGACY_MD5
        return url.checksum(algorithm: .md5, fromOffset: offset)
        #else
        do {
            let md5Hash = try calculateMD5Synchronously(of: url, startingAt: UInt64(offset))
            VLOG("MD5 Hash: \(md5Hash)")
            return md5Hash
        } catch {
            ELOG("An error occurred: \(error)\nFile: \(url)")

            // Post notification for file access error
            let nsError = error as NSError
            let errorType = determineErrorType(nsError)

            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .fileAccessError,
                    object: nil,
                    userInfo: [
                        "error": error.localizedDescription,
                        "errorType": errorType,
                        "path": url.path,
                        "filename": url.lastPathComponent,
                        "timestamp": Date()
                    ]
                )
            }

            return nil
        }
        #endif
    }
}

#if canImport(Combine)
/// Asynchronously reads a local file and calculates the MD5 checksum.
/// - Parameters:
///   - fileURL: The URL of the file.
///   - offset: An optional byte offset to start reading the file. Default is 0.
/// - Returns: A publisher emitting a single String of the computed MD5 hash.
func calculateMD5(of fileURL: URL, startingAt offset: UInt64 = 0) -> AnyPublisher<String, Error> {
    Deferred { // Use Deferred to ensure the Future is created only upon subscription
        Future<String, Error> { promise in
            calculateMD5Attempt(fileURL: fileURL, offset: offset, promise: promise)
        }
    }
    .catch { error -> AnyPublisher<String, Error> in
        // Check if the error is retryable
        if isRetryableError(error as NSError) {
            // If retryable, introduce a delay before retrying
            return Fail(error: error) // Emit the error to trigger retry
                .delay(for: .seconds(1), scheduler: DispatchQueue.global()) // Wait 1 second
                .eraseToAnyPublisher()
        } else {
            // If not retryable, fail immediately
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    .retry(2) // Retry 2 times after the initial attempt (total 3 attempts) for upstream failures
    .eraseToAnyPublisher()
}

/// Helper function to perform a single MD5 calculation attempt.
private func calculateMD5Attempt(fileURL: URL, offset: UInt64, promise: @escaping (Result<String, Error>) -> Void) {
    DispatchQueue.global(qos: .utility).async { // Perform file IO on a background thread
        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            defer { fileHandle.closeFile() }

            if offset > 0 {
                // Recommended way for macOS 10.15.4+ and iOS 13.4+
                if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *) {
                    try fileHandle.seek(toOffset: offset)
                } else {
                    // Fallback for older OS versions
                    fileHandle.seek(toFileOffset: offset)
                }
            }

            var hasher = Insecure.MD5()
            let bufferSize: Int = 1024 * 1024 // 1 MB

            while true {
                // Autorelease pool for efficient memory management during read loop
                let data = try autoreleasepool { () -> Data? in
                    if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *) {
                        return try fileHandle.read(upToCount: bufferSize)
                    } else {
                        // Fallback for older OS versions
                        return fileHandle.readData(ofLength: bufferSize)
                    }
                }

                guard let chunk = data, !chunk.isEmpty else {
                    break // End of file
                }
                hasher.update(data: chunk)
            }

            let result = hasher.finalize()
            let hashString = result.map { String(format: "%02x", $0) }.joined().uppercased()

            promise(.success(hashString))
        } catch {
            VLOG("calculateMD5Attempt failed for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            promise(.failure(error))
        }
    }
}

/// Computes the MD5 of a file on the **calling thread**.
///
/// This must never hand the work to another thread and wait for it. It used to
/// wrap the Combine pipeline above: it blocked the caller on a `DispatchSemaphore`
/// while the hashing was dispatched to `DispatchQueue.global(.utility)` and the
/// completion hopped again to `.userInitiated`. Callers on the Swift cooperative
/// pool — notably `GameImporter.preProcessQueue`'s `withTaskGroup`, via
/// `isBIOS` → `ImportQueueItem.md5` — parked every worker thread in
/// `semaphore_wait_trap`, leaving nothing to run the continuation that would
/// signal the semaphore. That deadlocked the importer permanently (proven by a
/// stack sample of the hung app on 2026-08-05: 10 threads, identical stack).
///
/// Hashing directly on the caller keeps the same blocking duration and the exact
/// same result, but makes the deadlock structurally impossible: no second thread
/// is required for this call to finish.
func calculateMD5Synchronously(of fileURL: URL, startingAt offset: UInt64 = 0) throws -> String {
    var md5Hash: String = ""
    var returnedError: Error?

    // Mirrors the previous pipeline's `.retry(2)`: three attempts total, with a
    // 1 second pause before retrying, and only for retryable errors.
    let maxAttempts = 3
    for attempt in 1...maxAttempts {
        do {
            md5Hash = try _computeMD5(of: fileURL, startingAt: offset)
            returnedError = nil
            break
        } catch {
            VLOG("calculateMD5 attempt \(attempt) failed for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            returnedError = error
            guard attempt < maxAttempts, isRetryableError(error as NSError) else { break }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    if let error = returnedError {
        // Log the final error after retries (if any) have failed
        ELOG("MD5 calculation failed after retries for \(fileURL.lastPathComponent): \(error.localizedDescription)")
        throw error
    }

    // Check if hash is empty, which might indicate an issue not caught as an error
    guard !md5Hash.isEmpty else {
        ELOG("MD5 calculation for \(fileURL.lastPathComponent) resulted in an empty hash string.")
        // Throw a generic error or a more specific one if possible
        throw NSError(domain: "PVHashingErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "MD5 calculation produced an empty hash."])
    }

    return md5Hash.uppercased()
}

public extension URL {
    /// Returns a Combine publisher that emits the MD5 hash of the file.
    func calculateMD5(startingAt offset: UInt64 = 0) -> AnyPublisher<String, Error> {
        return PVHashing.calculateMD5(of: self, startingAt: offset)
    }

    /// Asynchronously computes the MD5 hash of the file using Swift structured concurrency.
    func md5Async(startingAt offset: UInt64 = 0) async throws -> String {
        try await calculateMD5Async(of: self, startingAt: offset)
    }

    /// Streams progress events and the final MD5 hash via `AsyncThrowingStream`.
    func md5Stream(startingAt offset: UInt64 = 0) -> AsyncThrowingStream<MD5HashingEvent, Error> {
        calculateMD5Stream(of: self, startingAt: offset)
    }
}

#else

/// Direct synchronous MD5 calculation without Combine (used on Linux)
func calculateMD5Synchronously(of fileURL: URL, startingAt offset: UInt64 = 0) throws -> String {
    return try _computeMD5(of: fileURL, startingAt: offset)
}

public extension URL {
    /// Asynchronously computes the MD5 hash of the file using Swift structured concurrency.
    func md5Async(startingAt offset: UInt64 = 0) async throws -> String {
        try await calculateMD5Async(of: self, startingAt: offset)
    }

    /// Streams progress events and the final MD5 hash via `AsyncThrowingStream`.
    func md5Stream(startingAt offset: UInt64 = 0) -> AsyncThrowingStream<MD5HashingEvent, Error> {
        calculateMD5Stream(of: self, startingAt: offset)
    }
}
#endif

// MARK: - Error Handling Helpers

/// Determine the type of error for better user feedback
func determineErrorType(_ error: NSError) -> String {
    // Check for timeout errors
    if error.domain == NSPOSIXErrorDomain && error.code == 60 {
        return "timeout"
    }

    // Check for file access errors
    if error.domain == NSCocoaErrorDomain && error.code == 256 {
        return "access_denied"
    }

    // Check for iCloud-related errors
    if error.domain == NSCocoaErrorDomain &&
       (error.userInfo[NSUnderlyingErrorKey] as? NSError)?.domain == NSPOSIXErrorDomain {
        return "icloud_access"
    }

    // Check for NSFileProviderInternalErrorDomain errors (iCloud file provider errors)
    if error.domain == "NSFileProviderInternalErrorDomain" {
        return "file_provider_error"
    }

    return "unknown"
}

/// Determine if an error is retryable
func isRetryableError(_ error: NSError) -> Bool {
    // Timeout errors are retryable
    if error.domain == NSPOSIXErrorDomain && error.code == 60 {
        return true
    }

    // Some file access errors might be temporary
    if error.domain == NSCocoaErrorDomain && error.code == 256 {
        // Check if it's a temporary file system issue
        let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError
        if underlyingError?.domain == NSPOSIXErrorDomain && underlyingError?.code == 0 {
            return true
        }
    }

    return false
}
