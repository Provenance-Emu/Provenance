// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension Data {

    @inline(__always)
    func toU16() -> UInt16 {
        #if compiler(>=5.0)
            return self.withUnsafeBytes { $0.bindMemory(to: UInt16.self)[0] }
        #else
            return self.withUnsafeBytes { $0.pointee }
        #endif
    }

    @inline(__always)
    func toU32() -> UInt32 {
        #if compiler(>=5.0)
            return self.withUnsafeBytes { $0.bindMemory(to: UInt32.self)[0] }
        #else
            return self.withUnsafeBytes { $0.pointee }
        #endif
    }

    @inline(__always)
    func toU64() -> UInt64 {
        #if compiler(>=5.0)
            return self.withUnsafeBytes { $0.bindMemory(to: UInt64.self)[0] }
        #else
            return self.withUnsafeBytes { $0.pointee }
        #endif
    }

    @inline(__always)
    func toByteArray(_ count: Int) -> [UInt8] {
        #if compiler(>=5.0)
            return self.withUnsafeBytes { $0.map { $0 } }
        #else
            return self.withUnsafeBytes {
                [UInt8](UnsafeBufferPointer(start: $0, count: count))
            }
        #endif
    }

}
