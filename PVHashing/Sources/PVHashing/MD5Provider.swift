import Foundation

/// Protocol for MD5 computation
public protocol MD5Provider {
    func md5ForFile(at url: URL, fromOffset offset: UInt) -> String?
}
