import Foundation

/// Protocol for MD5 computation.
public protocol MD5Provider {
    /// Synchronously compute the MD5 hash of a file, returning `nil` on failure.
    func md5ForFile(at url: URL, fromOffset offset: UInt) -> String?

    /// Asynchronously compute the MD5 hash of a file.
    ///
    /// A default implementation is provided that delegates to `calculateMD5Async`.
    /// Conforming types may override this to provide custom behaviour.
    func md5ForFileAsync(at url: URL, fromOffset offset: UInt) async throws -> String

    /// Stream progress events and the final MD5 hash for a file.
    ///
    /// A default implementation is provided that delegates to `calculateMD5Stream`.
    func md5StreamForFile(at url: URL, fromOffset offset: UInt) -> AsyncThrowingStream<MD5HashingEvent, Error>
}

public extension MD5Provider {
    func md5ForFileAsync(at url: URL, fromOffset offset: UInt = 0) async throws -> String {
        try await calculateMD5Async(of: url, startingAt: UInt64(offset))
    }

    func md5StreamForFile(at url: URL, fromOffset offset: UInt = 0) -> AsyncThrowingStream<MD5HashingEvent, Error> {
        calculateMD5Stream(of: url, startingAt: UInt64(offset))
    }
}
