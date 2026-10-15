//
//  PatchTypes.swift
//  PVPatchEngine
//
//  Public value types of the patch engine. The format list, option naming and
//  error cases follow Provenance PVPatching, narrowed to the formats that can be
//  applied by streaming.
//

import Foundation

/// A patch file format the engine can apply.
public enum PatchFormat: String, CaseIterable, Sendable, Codable {
    /// International Patching System, 3-byte offsets (images up to 16 MiB).
    case ips
    /// IPS with 4-byte offsets and an "EEOF" terminator.
    case ips32
    /// Beat Patch System, with source, target and patch CRC32.
    case bps
    /// Universal Patch System, with source, target and patch CRC32.
    case ups
    /// PlayStation Patch Format, versions 1 to 3.
    case ppf
    /// xdelta3 / VCDIFF (RFC 3284).
    case xdelta3

    /// File extensions (lowercase, no dot) usually used for this format.
    public var fileExtensions: [String] {
        switch self {
        case .ips: return ["ips"]
        case .ips32: return ["ips32"]
        case .bps: return ["bps"]
        case .ups: return ["ups"]
        case .ppf: return ["ppf"]
        case .xdelta3: return ["xdelta", "xdelta3", "vcdiff"]
        }
    }

    /// Name for display in UI.
    public var displayName: String {
        switch self {
        case .ips: return "IPS"
        case .ips32: return "IPS32"
        case .bps: return "BPS"
        case .ups: return "UPS"
        case .ppf: return "PPF"
        case .xdelta3: return "xdelta3"
        }
    }

    /// Every extension of every supported format, for file pickers.
    public static var allFileExtensions: [String] {
        allCases.flatMap(\.fileExtensions)
    }
}

/// Everything that can go wrong while inspecting or applying a patch.
public enum PatchError: Error, Sendable {
    /// The source does not match the checksum recorded in the patch (CRC32, or adler32 for xdelta3).
    case sourceMismatch(expected: UInt32, actual: UInt32)
    /// The source is not the size the patch was made for.
    case sourceSizeMismatch(expected: UInt64, actual: UInt64)
    /// The patched result does not match the target checksum recorded in the patch.
    case targetMismatch(expected: UInt32, actual: UInt32)
    /// The patch file ends before its data does.
    case truncatedPatch
    /// The patch is malformed or fails its own integrity check.
    case corruptPatch(String)
    /// The file is not a patch format the engine supports.
    case unsupportedFormat
    /// An xdelta3 patch uses a secondary compressor (for example LZMA) that is not built in.
    case unsupportedSecondaryCompression
    /// The patched image would be larger than `PatchOptions.maxOutputSize`.
    case outputTooLarge
    /// The surrounding task was cancelled.
    case cancelled
    /// A file operation failed.
    case io(Error)
}

extension PatchError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .sourceMismatch(expected, actual):
            return String(format: "The source file is not the one this patch was made for (checksum %08X, expected %08X).", actual, expected)
        case let .sourceSizeMismatch(expected, actual):
            return "The source file is \(actual) bytes but the patch expects \(expected)."
        case let .targetMismatch(expected, actual):
            return String(format: "The patched file failed verification (checksum %08X, expected %08X).", actual, expected)
        case .truncatedPatch:
            return "The patch file is incomplete."
        case let .corruptPatch(reason):
            return "The patch file is damaged: \(reason)."
        case .unsupportedFormat:
            return "This is not a supported patch format."
        case .unsupportedSecondaryCompression:
            return "This xdelta patch uses a compression method (such as LZMA) that is not supported."
        case .outputTooLarge:
            return "The patched file would be larger than allowed."
        case .cancelled:
            return "Patching was cancelled."
        case let .io(error):
            return error.localizedDescription
        }
    }
}

/// The secondary compressor an xdelta3 patch's data sections are compressed with.
public enum SecondaryCompression: Sendable, Equatable {
    case djw
    case lzma
    case fgk
    /// A compressor id xdelta3 does not define.
    case unknown(UInt8)

    /// xdelta3's header ids: 1 = DJW, 2 = LZMA, 16 = FGK.
    init(compressorID: UInt8) {
        switch compressorID {
        case 1: self = .djw
        case 2: self = .lzma
        case 16: self = .fgk
        default: self = .unknown(compressorID)
        }
    }

    /// Whether the engine can decode it. DJW and FGK are built in; LZMA is not.
    public var isSupported: Bool {
        switch self {
        case .djw, .fgk: return true
        case .lzma, .unknown: return false
        }
    }
}

/// Metadata a patch declares about itself, read without applying it.
public struct PatchInfo: Sendable, Equatable {
    public var format: PatchFormat
    /// Size of the patch file.
    public var patchSize: UInt64
    /// Size of the image the patch expects, when the format records it (BPS, UPS, PPF 2.0).
    /// nil for xdelta3, whose patches do not record it; see `minimumSourceSize`.
    public var sourceSize: UInt64?
    /// xdelta3 only: the furthest source byte the patch reads, so the smallest source it can apply to.
    /// It is a lower bound, not a declared size; do not match it for equality.
    public var minimumSourceSize: UInt64?
    /// xdelta3 only: the secondary compressor the patch declares; nil when it declares none. Check
    /// `isSupported` before unpacking a large source, because `apply` reports an unsupported one only
    /// when it runs.
    public var secondaryCompression: SecondaryCompression?
    /// Size of the image the patch produces, when the format records it.
    public var targetSize: UInt64?
    public var sourceCRC32: UInt32?
    public var targetCRC32: UInt32?
    public var patchCRC32: UInt32?
    /// Free text carried by the patch: the PPF description or the BPS metadata.
    public var description: String?
    /// Whether applying the patch can check the source or the result against something the patch carries:
    /// a BPS or UPS checksum, a PPF block check, or xdelta3 window checksums. False for IPS and IPS32, and
    /// for PPF and xdelta3 patches whose author left the checks out. Applying such a patch can silently
    /// produce a wrong image from the wrong disc, so do not overwrite the only copy of a source with it.
    public var canVerifyIntegrity = false
}

/// Knobs for `PatchEngine.apply`.
public struct PatchOptions: Sendable {
    /// Apply even when the source does not match what the patch was made for.
    ///
    /// Skips the source CRC32 (BPS, UPS), the size and block checks (PPF), the declared source size
    /// and the per-window adler32 (xdelta3). Because a different source yields a different result,
    /// a target CRC32 mismatch is then reported in `PatchResult.ignoredTargetMismatch` instead of thrown.
    public var ignoreSourceChecksum: Bool
    /// Largest output the engine will write, in bytes.
    public var maxOutputSize: UInt64

    public static let defaultMaxOutputSize: UInt64 = 64 * 1024 * 1024 * 1024

    public init(ignoreSourceChecksum: Bool = false, maxOutputSize: UInt64 = PatchOptions.defaultMaxOutputSize) {
        self.ignoreSourceChecksum = ignoreSourceChecksum
        self.maxOutputSize = maxOutputSize
    }
}

/// Progress of a running `PatchEngine.apply`.
public struct PatchProgress: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        /// Reading the source to check it against the patch.
        case verifying
        /// Writing the patched image.
        case patching
    }

    public var phase: Phase
    /// 0 ... 1 over the whole operation.
    public var fractionCompleted: Double
}

/// A checksum that was compared and matched.
public enum VerifiedChecksum: Sendable, Equatable {
    case sourceCRC32(UInt32)
    case targetCRC32(UInt32)
    case patchCRC32(UInt32)
    /// The 1 KiB block check of a PPF patch.
    case sourceBlockCheck
    /// The adler32 of every xdelta3 target window that carried one.
    case targetWindowAdler32(windows: Int)
}

/// A target checksum that did not match, when the caller asked to ignore the source checksum.
public struct ChecksumMismatch: Sendable, Equatable {
    public var expected: UInt32
    public var actual: UInt32
}

/// What `PatchEngine.apply` produced.
public struct PatchResult: Sendable, Equatable {
    /// The patched image (the `output` URL that was passed in).
    public var output: URL
    public var bytesWritten: UInt64
    /// Every checksum the format carries that was checked and matched.
    public var verifiedChecksums: [VerifiedChecksum]
    /// Set only with `ignoreSourceChecksum` when the result differs from the target the patch describes.
    public var ignoredTargetMismatch: ChecksumMismatch?

    /// Whether the source or the result was checked against the patch and matched. A patch checksum alone
    /// does not count: it proves the patch file is intact, not that it was made for this source.
    public var checkedAgainstSource: Bool {
        verifiedChecksums.contains { check in
            switch check {
            case .sourceCRC32, .targetCRC32, .sourceBlockCheck: return true
            case let .targetWindowAdler32(windows): return windows > 0
            case .patchCRC32: return false
            }
        }
    }
}
