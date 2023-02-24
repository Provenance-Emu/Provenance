import CryptoKit
import Foundation

public extension String {
    var MD5: String {
        let computed = Insecure.MD5.hash(data: data(using: .utf8)!)
        return computed.map { String(format: "%02hhx", $0) }.joined()
    }
}
