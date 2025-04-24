import Checksum
import Foundation
import PVLogging

/// Notification names for file access errors and coordination
public extension Notification.Name {
    static let fileAccessError = Notification.Name("fileAccessError")
    static let checkFileRecoveryStatus = Notification.Name("checkFileRecoveryStatus")
    static let fileRecoveryStatusResponse = Notification.Name("fileRecoveryStatusResponse")
}

extension FileManager: MD5Provider {
    public func md5ForFile(at url: URL, fromOffset offset: UInt = 0) -> String? {
        // Check if the file is currently being recovered from iCloud using a notification-based approach
        let semaphore = DispatchSemaphore(value: 0)
        var isBeingRecovered = false
        
        // Set up observer for the response
        let observer = NotificationCenter.default.addObserver(
            forName: .fileRecoveryStatusResponse,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let path = userInfo["path"] as? String,
               path == url.path,
               let status = userInfo["isBeingRecovered"] as? Bool {
                isBeingRecovered = status
            }
            semaphore.signal()
        }
        
        // Post notification to check if file is being recovered
        NotificationCenter.default.post(
            name: .checkFileRecoveryStatus,
            object: nil,
            userInfo: ["path": url.path]
        )
        
        // Wait for response with a timeout
        _ = semaphore.wait(timeout: .now() + 0.1)
        
        // Remove observer
        NotificationCenter.default.removeObserver(observer)
        
        if isBeingRecovered {
            ILOG("Skipping MD5 calculation for file being recovered: \(url.lastPathComponent)")
            
            // Post notification about pending file
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .fileAccessError,
                    object: nil,
                    userInfo: [
                        "error": "File is currently being recovered from iCloud",
                        "errorType": "file_recovering",
                        "path": url.path,
                        "filename": url.lastPathComponent,
                        "timestamp": Date()
                    ]
                )
            }
            
            return nil
        }
        
        #if LEGACY_MD5
        return url.checksum(algorithm: .md5, fromOffset: offset)
        #else
        do {
            let md5Hash = try calculateMD5Synchronously(of: url, startingAt: UInt64(offset))
            VLOG("MD5 Hash: \(md5Hash)")
            return md5Hash
        } catch {
            ELOG("An error occurred: \(error)")
            
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

import CryptoKit
import Combine

/// Asynchronously reads a local file and calculates the MD5 checksum.
/// - Parameters:
///   - fileURL: The URL of the file.
///   - offset: An optional byte offset to start reading the file. Default is 0.
/// - Returns: A publisher emitting a single String of the computed MD5 hash.
func calculateMD5(of fileURL: URL, startingAt offset: UInt64 = 0) -> AnyPublisher<String, Error> {
    Deferred {
        Future<String, Error> { promise in
            do {
                let fileHandle = try FileHandle(forReadingFrom: fileURL)
                if offset > 0, #available(iOS 13.4, *) {
                    try fileHandle.seek(toOffset: offset)
                } else if offset > 0 {
                    fileHandle.seek(toFileOffset: offset)
                }

                var hasher = Insecure.MD5()
                let bufferSize: Int = 1024 * 1024 // 1 MB
                while try autoreleasepool(invoking: {
                    guard let data = try fileHandle.read(upToCount: bufferSize) else {
                        return false
                    }
                    if data.count > 0 {
                        hasher.update(data: data)
                        return true // Continue
                    }
                    return false // End of file reached
                }) {}

                fileHandle.closeFile()

                let result = hasher.finalize()
                let hashString = result.map { String(format: "%02x", $0) }.joined()

                promise(.success(hashString))
            } catch {
                promise(.failure(error))
            }
        }
    }.eraseToAnyPublisher()
}

func calculateMD5Synchronously(of fileURL: URL, startingAt offset: UInt64 = 0) throws -> String {
    let semaphore = DispatchSemaphore(value: 0)
    var md5Hash: String = ""
    var returnedError: Error?

    let subscription = calculateMD5(of: fileURL, startingAt: offset)
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                semaphore.signal()
            case .failure(let error):
                returnedError = error
                semaphore.signal()
            }
        }, receiveValue: { hash in
            md5Hash = hash
        })

    semaphore.wait()
    subscription.cancel()

    if let error = returnedError {
        // Handle the error appropriately in your application context.
        ELOG("Error occurred: \(error)")
        
        // For specific errors like timeouts or file access issues, add retry logic
        let nsError = error as NSError
        if isRetryableError(nsError) {
            ILOG("Encountered retryable error, attempting retry: \(error.localizedDescription)")
            
            // Add a small delay before retry
            Thread.sleep(forTimeInterval: 0.5)
            
            do {
                // Try one more time with a direct file read approach
                let data = try Data(contentsOf: fileURL, options: .alwaysMapped)
                var hasher = Insecure.MD5()
                hasher.update(data: data)
                let result = hasher.finalize()
                let hashString = result.map { String(format: "%02x", $0) }.joined()
                return hashString
            } catch {
                ELOG("Retry also failed: \(error.localizedDescription)")
                throw error
            }
        }
        
        throw error
    }

    return md5Hash
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

//// Example usage:
//let fileURL = URL(fileURLWithPath: "/path/to/your/file")
//calculateMD5(of: fileURL, startingAt: 1024)
//    .sink(receiveCompletion: { completion in
//        if case .failure(let error) = completion {
//            print("Failed with error: \(error)")
//        }
//    }, receiveValue: { md5Hash in
//        print("MD5 Hash: \(md5Hash)")
//    })
//    .cancel() // Be sure to store the Cancellable in a property if you want the operation to complete.
