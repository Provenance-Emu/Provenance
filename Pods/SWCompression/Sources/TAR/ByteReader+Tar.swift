// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

extension ByteReader {

    /**
     Reads a `String` field from TAR container. The end of the field is defined by either:
     1. NULL character (thus CString in the name of the function).
     2. Reaching specified maximum length.

     Strings are encoded in TAR using ASCII encoding. We are treating them as UTF-8 encoded instead since UTF-8 is
     backwards compatible with ASCII.

     We use `String(cString:)` initalizer because TAR's NULL-ending ASCII fields are basically CStrings (especially,
     since we are treating them as UTF-8 strings). As a bonus, this initializer is not failable: it replaces unparsable
     as UTF-8 sequences of bytes with UTF-8 Replacement Character, so we don't need to throw any error.
     */
    func tarCString(maxLength: Int) -> String {
        var buffer = self.bytes(count: maxLength)
        if buffer.last != 0 {
            buffer.append(0)
        }
        return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    /**
     Reads an `Int` field from TAR container. The end of the field is defined by either:
     1. NULL or SPACE (in containers created by certain old implementations) character.
     2. Reaching specified maximum length.

     Integers are encoded in TAR as ASCII text. We are treating them as UTF-8 encoded strings since UTF-8 is backwards
     compatible with ASCII.

     Integers can also be encoded as non-decimal based number. This is controlled by `radix` parameter.
     */
    func tarInt(maxLength: Int) -> Int? {
        guard maxLength > 0
            else { return nil }

        var buffer = [UInt8]()
        buffer.reserveCapacity(maxLength)

        let firstByte = self.byte()
        self.offset -= 1

        if firstByte & 0x80 != 0 { // Base-256 encoding; used for big numeric fields.
            buffer = self.bytes(count: maxLength)
            /// Inversion mask for handling negative numbers.
            let invMask = buffer[0] & 0x40 != 0 ? 0xFF : 0x00
            var result = 0
            for i in 0..<buffer.count {
                var byte = buffer[i].toInt() ^ invMask
                if i == 0 {
                    byte &= 0x7F // Ignoring bit which indicates base-256 encoding.
                }
                if result >> (Int.bitWidth - 8) > 0 {
                    return nil // Integer overflow
                }
                result = (result << 8) | byte
            }
            if result >> (Int.bitWidth - 1) > 0 {
                return nil // Integer overflow
            }
            return invMask == 0xFF ? ~result : result
        }

        // Normal, octal encoding.
        let startOffset = self.offset

        // Skip leading NULLs and whitespaces (used by some implementations).
        var byte: UInt8
        var actualStartIndex = 0
        repeat {
            byte = self.byte()
            actualStartIndex += 1
        } while (byte == 0 || byte == 0x20) && (actualStartIndex < maxLength)
        self.offset -= 1

        for _ in actualStartIndex..<maxLength {
            let byte = self.byte()
            guard byte != 0 && byte != 0x20
                else { break }
            buffer.append(byte)
        }
        self.offset = startOffset + maxLength
        guard let string = String(bytes: buffer, encoding: .utf8)
            else { return nil }
        return Int(string, radix: 8)
    }

}
