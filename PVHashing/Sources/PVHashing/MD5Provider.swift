import Foundation

/// Protocol for MD5 computation
public protocol MD5Provider {
    func md5ForFile(atPath path: String, fromOffset offset: UInt) -> String?
}
