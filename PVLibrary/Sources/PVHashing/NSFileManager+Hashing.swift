import Checksum
import Foundation
import PVLogging

@objc
public extension FileManager {
    func md5ForFile(atPath path: String, fromOffset offset: FileSize = 0) -> String? {
        guard let url = URL(string: path) else {
            ELOG("File path URL invalid")
            return nil
        }
        return url.checksum(algorithm: .md5, fromOffset: offset)
    }
}
