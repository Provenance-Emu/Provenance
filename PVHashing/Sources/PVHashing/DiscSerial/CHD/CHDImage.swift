//
//  CHDImage.swift
//  PVHashing
//
//  Reads single hunks out of a CHD v5 file, compressed or not, without
//  decompressing the rest. Written from MAME's CHD format (chd.cpp, chdcodec.cpp)
//  for the serial extractor, which needs a handful of sectors per disc.
//
//  Codecs read: none, zlib, lzma, cdzl, cdlz. Codecs not read: zstd, cdzs,
//  flac, cdfl, huff, avhu. A hunk in one of those returns nil; other hunks of
//  the same file still read. Parent (delta) CHDs are not followed.
//

import Foundation
#if canImport(Compression)
import Compression
#endif

final class CHDImage {

    // MARK: Header

    private enum Layout {
        static let magic = Array("MComprHD".utf8)
        static let headerLength = 124
        static let version = 12
        static let compressors = 16
        static let logicalBytes = 32
        static let mapOffset = 40
        static let hunkBytes = 56
        static let unitBytes = 60
        static let supportedVersion: UInt32 = 5
        static let uncompressedMapEntryLength: UInt64 = 4
    }

    /// Limits that reject a corrupt or hostile file before any arithmetic or allocation.
    private enum Limit {
        static let unitBytes: UInt64 = 1 << 20
        static let hunkBytes: UInt64 = 64 << 20
        static let hunkCount: UInt64 = 1 << 24
        static let selfReferenceDepth = 4
    }

    /// CD frames as CHD stores them: 2352 bytes of sector data, then 96 of subcode.
    enum CDFrame {
        static let bytes = 2448
        static let sectorBytes = 2352
        static let sync: [UInt8] = [0x00] + [UInt8](repeating: 0xFF, count: 10) + [0x00]
    }

    private enum Codec {
        static let zlib = fourCC("zlib")
        static let lzma = fourCC("lzma")
        static let cdZlib = fourCC("cdzl")
        static let cdLzma = fourCC("cdlz")

        static func fourCC(_ text: String) -> UInt32 {
            text.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
        }
    }

    let hunkBytes: Int
    let unitBytes: Int
    let hunkCount: Int

    private let handle: FileHandle
    private let compressors: [UInt32]
    private let mapOffset: UInt64
    private var compressedMap: CHDCompressedMap?
    private var cachedHunk: (index: Int, data: Data)?

    /// Nil when the file is not a CHD v5 this reader can address.
    init?(handle: FileHandle) {
        guard (try? handle.seek(toOffset: 0)) != nil,
              let header = try? handle.read(upToCount: Layout.headerLength),
              header.count == Layout.headerLength,
              Array(header.prefix(Layout.magic.count)) == Layout.magic,
              header.loadBE32(at: Layout.version) == Layout.supportedVersion else { return nil }

        let hunkBytes = UInt64(header.loadBE32(at: Layout.hunkBytes))
        let unitBytes = UInt64(header.loadBE32(at: Layout.unitBytes))
        let logicalBytes = header.loadBE64(at: Layout.logicalBytes)
        let mapOffset = header.loadBE64(at: Layout.mapOffset)
        guard hunkBytes > 0, hunkBytes <= Limit.hunkBytes,
              unitBytes > 0, unitBytes <= Limit.unitBytes, unitBytes <= hunkBytes,
              mapOffset > 0, logicalBytes > 0 else { return nil }
        let hunkCount = (logicalBytes - 1) / hunkBytes + 1
        guard hunkCount <= Limit.hunkCount else { return nil }

        self.handle = handle
        self.hunkBytes = Int(hunkBytes)
        self.unitBytes = Int(unitBytes)
        self.hunkCount = Int(hunkCount)
        self.mapOffset = mapOffset
        compressors = (0..<4).map { header.loadBE32(at: Layout.compressors + $0 * 4) }

        if compressors[0] != 0 {
            guard let map = CHDCompressedMap(handle: handle, at: mapOffset, hunkCount: Int(hunkCount),
                                          hunkBytes: Int(hunkBytes), unitBytes: Int(unitBytes)) else { return nil }
            compressedMap = map
        }
    }

    // MARK: Reading

    /// One unit (a CD frame or a DVD sector), or nil when its hunk cannot be read.
    func unit(_ index: Int) -> Data? {
        guard index >= 0 else { return nil }
        let unitsPerHunk = hunkBytes / unitBytes
        guard let hunk = hunk(index / unitsPerHunk) else { return nil }
        let start = (index % unitsPerHunk) * unitBytes
        guard start + unitBytes <= hunk.count else { return nil }
        return hunk.subdata(in: (hunk.startIndex + start)..<(hunk.startIndex + start + unitBytes))
    }

    /// One whole hunk, decompressed.
    func hunk(_ index: Int) -> Data? {
        if let cached = cachedHunk, cached.index == index { return cached.data }
        guard let data = readHunk(index, depth: 0) else { return nil }
        cachedHunk = (index, data)
        return data
    }

    private func readHunk(_ index: Int, depth: Int) -> Data? {
        guard index >= 0, index < hunkCount, depth <= Limit.selfReferenceDepth else { return nil }
        guard let entry = mapEntry(index) else { return nil }
        switch entry.type {
        case .stored:
            guard entry.length > 0 else { return Data(count: hunkBytes) }
            return read(at: entry.offset, count: hunkBytes)
        case .copyOfHunk:
            guard entry.offset < UInt64(hunkCount) else { return nil }
            return readHunk(Int(entry.offset), depth: depth + 1)
        case .codec0, .codec1, .codec2, .codec3:
            guard entry.length > 0, entry.length <= hunkBytes,
                  let packed = read(at: entry.offset, count: entry.length) else { return nil }
            return decompress(packed, codec: compressors[Int(entry.type.rawValue)])
        default:
            return nil
        }
    }

    private func mapEntry(_ index: Int) -> CHDMapEntry? {
        if let entry = compressedMap?.entry(index) { return entry }
        guard compressedMap == nil else { return nil }
        // An uncompressed map holds one big-endian hunk number per hunk.
        guard let raw = read(at: mapOffset + UInt64(index) * Layout.uncompressedMapEntryLength,
                             count: Int(Layout.uncompressedMapEntryLength)) else { return nil }
        let position = UInt64(raw.loadBE32(at: 0))
        // A hunk that was never written reads as zeros; a zero length marks it.
        guard position > 0 else { return CHDMapEntry(type: .stored, offset: 0, length: 0) }
        return CHDMapEntry(type: .stored, offset: position * UInt64(hunkBytes), length: hunkBytes)
    }

    private func read(at offset: UInt64, count: Int) -> Data? {
        guard (try? handle.seek(toOffset: offset)) != nil,
              let data = try? handle.read(upToCount: count), data.count == count else { return nil }
        return data
    }

    // MARK: Codecs

    private func decompress(_ packed: Data, codec: UInt32) -> Data? {
        switch codec {
        case Codec.zlib:
            return Self.inflate(packed, size: hunkBytes)
        case Codec.lzma:
            return LZMADecoder.decode(packed, size: hunkBytes)
        case Codec.cdZlib:
            return cdHunk(packed) { Self.inflate($0, size: $1) }
        case Codec.cdLzma:
            return cdHunk(packed) { LZMADecoder.decode($0, size: $1) }
        default:
            return nil
        }
    }

    /// A CD hunk is: one flag bit per frame, the length of the packed sector data, the
    /// sector data of every frame packed as one stream, then the packed subcode.
    /// A set flag means chdman zeroed the frame's sync pattern and ECC before packing.
    /// The sync pattern is put back, since it tells a raw sector from a cooked one.
    /// The ECC and the subcode stay zero: nothing here reads them.
    private func cdHunk(_ packed: Data, decode: (Data, Int) -> Data?) -> Data? {
        let frames = hunkBytes / CDFrame.bytes
        let lengthBytes = hunkBytes < 65_536 ? 2 : 3
        let flagBytes = (frames + 7) / 8
        let headerBytes = flagBytes + lengthBytes
        guard frames > 0, packed.count > headerBytes else { return nil }

        let bytes = [UInt8](packed)
        var sectorLength = 0
        for index in 0..<lengthBytes {
            sectorLength = (sectorLength << 8) | Int(bytes[flagBytes + index])
        }
        guard sectorLength > 0, headerBytes + sectorLength <= bytes.count,
              let sectors = decode(Data(bytes[headerBytes..<(headerBytes + sectorLength)]), frames * CDFrame.sectorBytes)
        else { return nil }

        var hunk = Data(count: hunkBytes)
        for frame in 0..<frames {
            let source = sectors.startIndex + frame * CDFrame.sectorBytes
            let target = frame * CDFrame.bytes
            hunk.replaceSubrange(target..<(target + CDFrame.sectorBytes),
                                 with: sectors[source..<(source + CDFrame.sectorBytes)])
            if bytes[frame / 8] & (1 << UInt8(frame % 8)) != 0 {
                hunk.replaceSubrange(target..<(target + CDFrame.sync.count), with: CDFrame.sync)
            }
        }
        return hunk
    }

    /// Raw DEFLATE, which is what Apple's `COMPRESSION_ZLIB` reads. Not available off Apple platforms.
    private static func inflate(_ packed: Data, size: Int) -> Data? {
        #if canImport(Compression)
        guard !packed.isEmpty, size > 0 else { return nil }
        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { target -> Int in
            packed.withUnsafeBytes { source -> Int in
                guard let targetBase = target.bindMemory(to: UInt8.self).baseAddress,
                      let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(targetBase, size, sourceBase, packed.count, nil, COMPRESSION_ZLIB)
            }
        }
        return written == size ? output : nil
        #else
        return nil
        #endif
    }
}
