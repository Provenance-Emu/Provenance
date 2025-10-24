import Checksum
import Foundation
import PVLogging
import CryptoKit
import Combine

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

func calculateMD5Synchronously(of fileURL: URL, startingAt offset: UInt64 = 0) throws -> String {
    let semaphore = DispatchSemaphore(value: 0)
    var md5Hash: String = ""
    var returnedError: Error?

    // The publisher now handles retries internally
    let subscription = calculateMD5(of: fileURL, startingAt: offset)
        .receive(on: DispatchQueue.global(qos: .userInitiated)) // Ensure completion/value are handled off the main thread if caller is main
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                break // Success handled in receiveValue
            case .failure(let error):
                returnedError = error
            }
            semaphore.signal()
        }, receiveValue: { hash in
            md5Hash = hash
        })

    semaphore.wait()
    subscription.cancel() // Clean up subscription

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
    func calculateMD5(startingAt offset: UInt64 = 0) -> AnyPublisher<String, Error> {
        return PVHashing.calculateMD5(of: self, startingAt: offset)
    }
}

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
