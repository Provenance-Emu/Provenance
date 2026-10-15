//
//  FixtureData.swift
//  PVPatchEngineTests
//
//  Deterministic source and target images behind the committed xdelta3 fixtures. The fixtures
//  hold only the patches; tests regenerate the images from this file, so changing it means
//  regenerating the fixtures (see Fixtures/README.txt).
//

import Foundation

enum FixtureData {
    private static let vocabulary: [[UInt8]] = [
        "GALE01", "Super Smash Bros", "Melee", "bomb-omb", "texture", "audio", "banner", "opening.bnr",
        "apploader", "fst.bin", "boot.bin", "bi2.bin", "\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}"
    ].map { Array($0.utf8) }

    /// Mildly compressible pseudo-random bytes: vocabulary words mixed with raw noise.
    static func bytes(seed: UInt64, count: Int) -> [UInt8] {
        var state = seed
        func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
        var output = [UInt8]()
        output.reserveCapacity(count + 16)
        while output.count < count {
            let value = next()
            if value & 3 == 0 {
                for shift in stride(from: 0, to: 64, by: 8) { output.append(UInt8(truncatingIfNeeded: value >> UInt64(shift))) }
            } else {
                output.append(contentsOf: vocabulary[Int(value >> 8) % vocabulary.count])
            }
        }
        return Array(output.prefix(count))
    }

    /// Literal data that secondary compression can shrink: four byte values in random order.
    static func lowEntropyBytes(seed: UInt64, count: Int) -> [UInt8] {
        bytes(seed: seed, count: count).map { [0x20, 0x41, 0x42, 0x0A][Int($0) & 3] }
    }

    static func xdeltaSource() -> [UInt8] {
        bytes(seed: 1, count: 300_000)
    }

    /// The source with a replaced run, two insertions, a deletion and an appended tail.
    static func xdeltaTarget() -> [UInt8] {
        var target = xdeltaSource()
        target.replaceSubrange(1_000..<1_100, with: bytes(seed: 2, count: 100))
        target.insert(contentsOf: bytes(seed: 3, count: 2_000), at: 150_000)
        target.insert(contentsOf: lowEntropyBytes(seed: 5, count: 30_000), at: 200_000)
        target.removeSubrange(280_000..<285_000)
        target.append(contentsOf: bytes(seed: 4, count: 3_500))
        return target
    }
}
