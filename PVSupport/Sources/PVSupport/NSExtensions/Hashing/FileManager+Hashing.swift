import Foundation
import CommonCrypto

public enum FileHashError: Error {
    case fileReadError
    case hashError
}

public extension FileManager {
    typealias FileHashes = (md5: String, crc: String)
    func digestsForFile(atPath url: URL, fromOffset headerSize: UInt64 = 0) throws -> FileHashes {
        do {
            let data = try data(atPath: url, atOffset: headerSize)

            // Compute the mD5 digest:
            let md5String = data.md5().toHexString().uppercased()

            // Compute the CRC32 digest:
            let crcString = data.crc32().toHexString().uppercased()

            let hashes: FileHashes = (md5: md5String, crc: crcString)
            return hashes
        } catch {
            ELOG("Cannot open file: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func data(atPath url: URL, atOffset headerSize: UInt64) throws -> Data {
        // Open file for reading:
        let file = try FileHandle(forReadingFrom: url)
        defer {
            file.closeFile()
        }

        try file.seek(toOffset: headerSize)
        let readData: Data?
        if #available(iOS 13.4, *) {
            readData = try file.readToEnd()
        } else {
            readData = file.readDataToEndOfFile()
        }
        guard let outputData = readData else {
            throw FileHashError.hashError
        }
        return outputData
    }
}

