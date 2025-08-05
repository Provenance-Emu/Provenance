import Foundation

/// Protocol for URLSession to enable dependency injection and testing
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Extension to make URLSession conform to the protocol
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
extension URLSession: URLSessionProtocol {}
