
import Foundation

public protocol FileOperationError: LocalizedError {
    var operationType: String { get }
    var sourcePath: String { get }
    var underlyingError: Error? { get }
}

public extension FileOperationError {
    var errorDescription: String? {
        if let underlying = underlyingError {
            return "[\(operationType)] Failed for \(sourcePath): \(underlying.localizedDescription)"
        } else {
            return "[\(operationType)] Failed for \(sourcePath)"
        }
    }
}
