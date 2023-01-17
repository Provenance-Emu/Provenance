import Foundation
import CommonCrypto

@objc
public extension FileManager {
    @objc
    public func md5ForFile(atPath path: String, fromOffset offset: UInt64 = 0) -> String? {
        return try? hash(ofFileAtPath: path, using: .md5, fromOffset: offset)
    }

//    @objc
//    public func md5(forFileAtPath path: String, fromOffset offset: UInt = 0) -> String? {
//        return try? hash(ofFileAtPath: path, using: .md5, fromOffset: offset)
//    }

    @objc
    func hash(ofFileAtPath path: String, using algorithm: HashAlgorithm, fromOffset offset: UInt64 = 0) throws -> String {
        let bufferSize = 1024 * 1024
        let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer {
            file.closeFile()
        }

        try file.seek(toOffset: offset)
        var context = algorithm.context()

        while let data = file.readData(ofLength: bufferSize), !data.isEmpty {
            data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                algorithm.update(context: &context, data: bytes, len: CC_LONG(data.count))
            }
        }

        var digest = Data(count: algorithm.digestLength)
        digest.withUnsafeMutableBytes { (digestBytes: UnsafeMutablePointer<UInt8>) -> Void in
            algorithm.final(digestBytes, context: &context)
        }

        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

@objc
public enum HashAlgorithm: Int {
    case md5, sha1, sha224, sha256, sha384, sha512

    func context() -> CC_MD5_CTX {
        var context = CC_MD5_CTX()
        switch self {
        case .md5:
            CC_MD5_Init(&context)
        case .sha1:
            CC_SHA1_Init(&context)
        case .sha224:
            CC_SHA224_Init(&context)
        case .sha256:
            CC_SHA256_Init(&context)
        case .sha384:
            CC_SHA384_Init(&context)
        case .sha512:
            CC_SHA512_Init(&context)
        }
        return context
    }

    func update(context: inout CC_MD5_CTX, data: UnsafePointer<UInt8>, len: CC_LONG) {
        switch self {
        case .md5:
            CC_MD5_Update(&context, data, len)
        case .sha1:
            CC_SHA1_Update(&context, data, len)
        case .sha224:
            CC_SHA224_Update(&context, data, len)
        case .sha256:
            CC_SHA256_Update(&context, data, len)
        case .sha384:
            CC_SHA384_Update(&context, data, len)
        case .sha512:
            CC_SHA512_Update(&context, data, len)
        }
    }

    func final(_ digest: UnsafeMutablePointer<UInt8>, context
}
