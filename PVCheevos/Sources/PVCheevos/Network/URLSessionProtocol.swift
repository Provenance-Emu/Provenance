import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Protocol for URLSession to enable dependency injection and testing
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Extension to make URLSession conform to the protocol
#if os(Linux)
extension URLSession: URLSessionProtocol {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }
            task.resume()
        }
    }
}
#else
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
extension URLSession: URLSessionProtocol {}
#endif
