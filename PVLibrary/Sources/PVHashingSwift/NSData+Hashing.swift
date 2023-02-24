import Foundation
import CryptoKit

@objc
public extension NSData {
    @objc var md5: String {
        let computed = Insecure.MD5.hash(data: self)
        return computed.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
    
    @objc var sha1: String {
        let computed = Insecure.SHA1.hash(data: self)
        return computed.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}

public extension Data {
    var md5: String {
        let computed = Insecure.MD5.hash(data: self)
        return computed.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
    
    var sha1: String {
        let computed = Insecure.SHA1.hash(data: self)
        return computed.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}
