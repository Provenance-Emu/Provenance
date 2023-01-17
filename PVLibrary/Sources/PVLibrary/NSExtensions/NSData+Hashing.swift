import Foundation

@objc
public extension NSData {
    @objc var md5: String {
        // TODO: Fix Me
        return ""
        //        let digestLength = Int(CC_MD5_DIGEST_LENGTH)
        //        let md5Buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: digestLength)
        //
        //        _ = withUnsafeBytes { (body: UnsafePointer<UInt8>) -> UInt8 in
        //            CC_MD5(body, CC_LONG(count), md5Buffer)
        //            return 0
        //        }
        //
        //        let output = (0..<digestLength).reduce("") { (output, i) -> String in
        //            return output + String(format: "%02x", md5Buffer[i])
        //        }
        //
        //        md5Buffer.deallocate()
        //
        //        return output
    }
    
    @objc var sha1: String {
        // TODO: Fix Me
        return ""
//        let digestLength = Int(CC_SHA1_DIGEST_LENGTH)
//        let sha1Buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: digestLength)
//
//        _ = withUnsafeBytes { (body: UnsafePointer<UInt8>) -> UInt8 in
//            CC_SHA1(body, CC_LONG(count), sha1Buffer)
//            return 0
//        }
//
//        let output = (0..<digestLength).reduce("") { (output, i) -> String in
//            return output + String(format: "%02x", sha1Buffer[i])
//        }
//
//        sha1Buffer.deallocate()
//
//        return output
    }
}
