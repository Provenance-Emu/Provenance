//
//  NDSDiscSerialPlugin.swift
//  PVHashing
//
//  Extracts product codes from Nintendo DS ROM dumps.
//

import Foundation
import PVLogging

/// Extracts product codes from Nintendo DS ROM images (`.nds`).
///
/// ## Format
/// Every NDS ROM begins with a fixed 512-byte header. The relevant fields are:
/// ```
/// Offset 0x00 – 0x0B  Game title (12 bytes, ASCII, null-padded)
/// Offset 0x0C – 0x0F  Game code  (4 bytes, ASCII, e.g. "AYLE")
/// Offset 0x10 – 0x11  Maker code (2 bytes, ASCII, e.g. "01")
/// Offset 0x12         Unit code  (0x00 = NDS, 0x02 = NDS+DSi, 0x03 = DSi)
/// ```
/// The serial is the concatenation of game code + maker code, e.g. `AYLE01`.
///
/// ## Magic
/// The NDS header has no single magic constant. Instead we check that:
/// - the game-code bytes (0x0C–0x0F) are all printable ASCII (A–Z, 0–9)
/// - the maker-code bytes (0x10–0x11) are all printable ASCII
///
/// We request 32 bytes so the magic check can look at both fields.
public struct NDSDiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["nds"]
    public let magicByteCount = 32

    public func matchesMagicBytes(_ headerBytes: Data) -> Bool {
        guard headerBytes.count >= 18 else { return false }
        // Game code: bytes 0x0C–0x0F must all be ASCII letters or digits.
        let gameCode = headerBytes[0x0C..<0x10]
        let makerCode = headerBytes[0x10..<0x12]
        // NDS game codes and maker codes use uppercase ASCII only.
        let allValid = (gameCode + makerCode).allSatisfy {
            ($0 >= 0x30 && $0 <= 0x39) ||  // '0'–'9'
            ($0 >= 0x41 && $0 <= 0x5A)     // 'A'–'Z'
        }
        return allValid
    }

    public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? {
        return await Task.detached(priority: .utility) {
            self._extractSerial(from: url, systemHint: systemHint)
        }.value
    }

    // MARK: - Implementation

    private func _extractSerial(from url: URL, systemHint: String?) -> DiscSerialResult? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            WLOG("NDSDiscSerialPlugin: cannot open \(url.lastPathComponent)")
            return nil
        }
        defer { try? handle.close() }

        guard (try? handle.seek(toOffset: 0)) != nil,
              let header = try? handle.read(upToCount: 32),
              header.count >= 18 else {
            VLOG("NDSDiscSerialPlugin: failed to read header from \(url.lastPathComponent)")
            return nil
        }

        guard let gameCode = header.asciiString(at: 0x0C, length: 4),
              let makerCode = header.asciiString(at: 0x10, length: 2),
              !gameCode.isEmpty, !makerCode.isEmpty else {
            VLOG("NDSDiscSerialPlugin: no valid game/maker code in \(url.lastPathComponent)")
            return nil
        }

        let serial = "\(gameCode)\(makerCode)".uppercased()
        ILOG("NDSDiscSerialPlugin: found serial '\(serial)' in \(url.lastPathComponent)")
        return DiscSerialResult(serial: serial, systemIdentifierHint: "com.provenance.nds")
    }
}
