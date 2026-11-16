//
//  CHDCompressedMap.swift
//  PVHashing
//
//  The hunk map of a compressed CHD v5 file, and the bit reader and Huffman
//  tree it is packed with. See CHDImage.swift.
//

import Foundation

/// How a hunk is stored, as the v5 map names it.
enum CHDHunkType: UInt8 {
    case codec0 = 0, codec1, codec2, codec3
    case stored = 4
    case copyOfHunk = 5
    case parent = 6
    case repeatSmall = 7
    case repeatLarge = 8
    case copyOfLast = 9
    case copyOfNext = 10
    case parentSame = 11
    case parentLast = 12
    case parentNext = 13
}

struct CHDMapEntry {
    let type: CHDHunkType
    let offset: UInt64
    let length: Int
}

/// The v5 map of a compressed CHD: a Huffman-coded run of hunk types for every hunk,
/// followed by each hunk's length and checksum. Offsets are running totals, so the
/// second part is decoded in order and only as far as the highest hunk asked for.
struct CHDCompressedMap {
    private let types: [CHDHunkType]
    private let lengthBits: Int
    private let selfBits: Int
    private let parentBits: Int
    private let hunkBytes: Int
    private let unitBytes: Int
    private var reader: CHDBitReader
    private var entries: [CHDMapEntry] = []
    private var nextOffset: UInt64
    private var lastSelf: UInt64 = 0
    private var lastParent: UInt64 = 0

    private enum Field {
        static let headerLength = 16
        static let maximumMapBytes = 64 << 20
        static let checksumBits = 16
        static let typeCodes = 16
        static let typeMaximumBits = 8
        static let smallRepeatBase = 2
        static let largeRepeatBase = 2 + 16
    }

    init?(handle: FileHandle, at offset: UInt64, hunkCount: Int, hunkBytes: Int, unitBytes: Int) {
        guard (try? handle.seek(toOffset: offset)) != nil,
              let header = try? handle.read(upToCount: Field.headerLength),
              header.count == Field.headerLength else { return nil }
        let mapBytes = Int(header.loadBE32(at: 0))
        // The first data offset is 48 bits wide: bytes 4 to 9.
        let firstOffset = header.loadBE64(at: 2) & 0x0000_FFFF_FFFF_FFFF
        guard mapBytes > 0, mapBytes <= Field.maximumMapBytes,
              let packed = try? handle.read(upToCount: mapBytes), packed.count == mapBytes else { return nil }

        lengthBits = Int(header[header.startIndex + 12])
        selfBits = Int(header[header.startIndex + 13])
        parentBits = Int(header[header.startIndex + 14])
        guard lengthBits <= 32, selfBits <= 32, parentBits <= 32 else { return nil }
        self.hunkBytes = hunkBytes
        self.unitBytes = unitBytes
        nextOffset = firstOffset
        reader = CHDBitReader(bytes: [UInt8](packed))

        guard let tree = CHDHuffmanTree(reader: &reader, codes: Field.typeCodes, maximumBits: Field.typeMaximumBits)
        else { return nil }
        var types: [CHDHunkType] = []
        types.reserveCapacity(hunkCount)
        var last = CHDHunkType.codec0
        var repeats = 0
        while types.count < hunkCount {
            if repeats > 0 {
                types.append(last)
                repeats -= 1
                continue
            }
            guard let type = CHDHunkType(rawValue: tree.decode(&reader)) else { return nil }
            switch type {
            case .repeatSmall:
                types.append(last)
                repeats = Field.smallRepeatBase + Int(tree.decode(&reader))
            case .repeatLarge:
                types.append(last)
                repeats = Field.largeRepeatBase + (Int(tree.decode(&reader)) << 4)
                repeats += Int(tree.decode(&reader))
            default:
                last = type
                types.append(type)
            }
        }
        self.types = types
    }

    mutating func entry(_ index: Int) -> CHDMapEntry? {
        guard index >= 0, index < types.count else { return nil }
        while entries.count <= index {
            entries.append(decodeNext())
        }
        return entries[index]
    }

    private mutating func decodeNext() -> CHDMapEntry {
        let hunk = UInt64(entries.count)
        let unitsPerHunk = UInt64(hunkBytes / unitBytes)
        switch types[entries.count] {
        case .codec0, .codec1, .codec2, .codec3:
            let length = Int(reader.read(lengthBits))
            reader.skip(Field.checksumBits)
            defer { nextOffset += UInt64(length) }
            return CHDMapEntry(type: types[entries.count], offset: nextOffset, length: length)
        case .stored:
            reader.skip(Field.checksumBits)
            defer { nextOffset += UInt64(hunkBytes) }
            return CHDMapEntry(type: .stored, offset: nextOffset, length: hunkBytes)
        case .copyOfHunk:
            lastSelf = UInt64(reader.read(selfBits))
            return CHDMapEntry(type: .copyOfHunk, offset: lastSelf, length: 0)
        case .copyOfNext:
            lastSelf += 1
            return CHDMapEntry(type: .copyOfHunk, offset: lastSelf, length: 0)
        case .copyOfLast:
            return CHDMapEntry(type: .copyOfHunk, offset: lastSelf, length: 0)
        case .parent:
            lastParent = UInt64(reader.read(parentBits))
            return CHDMapEntry(type: .parent, offset: lastParent, length: 0)
        case .parentSame:
            lastParent = hunk * unitsPerHunk
            return CHDMapEntry(type: .parent, offset: lastParent, length: 0)
        case .parentNext:
            lastParent += unitsPerHunk
            return CHDMapEntry(type: .parent, offset: lastParent, length: 0)
        case .parentLast:
            return CHDMapEntry(type: .parent, offset: lastParent, length: 0)
        case .repeatSmall, .repeatLarge:
            // Expanded while the types were read; never stored.
            return CHDMapEntry(type: .parent, offset: 0, length: 0)
        }
    }
}

// MARK: Bit reader and Huffman tree

/// Reads bits most significant first. Bits past the end read as zero.
private struct CHDBitReader {
    let bytes: [UInt8]
    private var bitPosition = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    /// Up to 32 bits, without consuming them.
    func peek(_ count: Int) -> UInt32 {
        guard count > 0 else { return 0 }
        let first = bitPosition >> 3
        var window: UInt64 = 0
        for index in 0..<5 {
            let byte = first + index < bytes.count ? bytes[first + index] : 0
            window = (window << 8) | UInt64(byte)
        }
        let shift = UInt64(40 - (bitPosition & 7) - count)
        return UInt32(truncatingIfNeeded: (window >> shift) & ((1 << UInt64(count)) - 1))
    }

    mutating func read(_ count: Int) -> UInt32 {
        defer { bitPosition += count }
        return peek(count)
    }

    mutating func skip(_ count: Int) {
        bitPosition += count
    }
}

/// MAME's canonical Huffman code: lengths are stored run-length coded, and longer
/// codes take the lower code values.
private struct CHDHuffmanTree {
    /// Indexed by the next `maximumBits` bits: the symbol in the high bits, its length in the low five.
    private let lookup: [UInt16]
    private let maximumBits: Int

    init?(reader: inout CHDBitReader, codes: Int, maximumBits: Int) {
        let lengthFieldBits = maximumBits >= 16 ? 5 : (maximumBits >= 8 ? 4 : 3)
        var lengths: [Int] = []
        lengths.reserveCapacity(codes)
        while lengths.count < codes {
            let length = Int(reader.read(lengthFieldBits))
            guard length == 1 else {
                lengths.append(length)
                continue
            }
            // A one escapes: "1 1" is a length of one, "1 n count" repeats n.
            let repeated = Int(reader.read(lengthFieldBits))
            if repeated == 1 {
                lengths.append(1)
            } else {
                let count = Int(reader.read(lengthFieldBits)) + 3
                guard lengths.count + count <= codes else { return nil }
                lengths.append(contentsOf: [Int](repeating: repeated, count: count))
            }
        }
        guard lengths.allSatisfy({ $0 <= maximumBits }) else { return nil }

        var histogram = [Int](repeating: 0, count: maximumBits + 1)
        for length in lengths { histogram[length] += 1 }
        var start = 0
        for length in stride(from: maximumBits, to: 0, by: -1) {
            let next = (start + histogram[length]) >> 1
            guard length == 1 || next * 2 == start + histogram[length] else { return nil }
            histogram[length] = start
            start = next
        }

        var lookup = [UInt16](repeating: 0, count: 1 << maximumBits)
        for (symbol, length) in lengths.enumerated() where length > 0 {
            let code = histogram[length]
            histogram[length] += 1
            let shift = maximumBits - length
            let low = code << shift
            let high = ((code + 1) << shift) - 1
            guard high < lookup.count else { return nil }
            for index in low...high {
                lookup[index] = UInt16(symbol << 5 | length)
            }
        }
        self.lookup = lookup
        self.maximumBits = maximumBits
    }

    func decode(_ reader: inout CHDBitReader) -> UInt8 {
        let entry = lookup[Int(reader.peek(maximumBits))]
        reader.skip(Int(entry & 0x1F))
        return UInt8(entry >> 5)
    }
}
