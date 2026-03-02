import CryptoKit
import Foundation

public extension String {
    var MD5: String {
        let computed = Insecure.MD5.hash(data: data(using: .utf8)!)
        return computed.map { String(format: "%02hhX", $0) }.joined()
    }
    
    var md5Hash: String {
        return self.MD5
    }
}
