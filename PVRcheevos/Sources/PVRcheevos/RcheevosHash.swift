//
//  RcheevosHash.swift
//  PVRcheevos
//
//  Console-aware ROM hashing for RetroAchievements.
//
//  Mirrors the hashing approach used by RetroArch's own cheevos.c, which calls
//  `rc_client_begin_identify_and_load_game(client, RC_CONSOLE_UNKNOWN, path,
//  data, size, …)` and lets rcheevos auto-detect the console from the file
//  extension / contents. We don't have access to the rc_client identify-and-
//  load API (gated behind `RC_CLIENT_SUPPORTS_HASH`), so we replicate the
//  auto-detect step ourselves with `rc_hash_initialize_iterator` +
//  `rc_hash_iterate` and feed the resulting hash through the existing
//  REST + `rc_client_begin_load_game` flow.
//
//  RA does NOT use a flat MD5 of the ROM file. The expected hash format is
//  console-specific:
//    • Cartridge systems with headers (iNES NES, A78) — header is stripped before MD5.
//    • Byte-swapped N64 (.n64/.v64) — bytes are rotated to z64 first.
//    • CD-based systems (PSX/Saturn/PCE-CD/Sega CD/Dreamcast/3DO/CDi/Jaguar CD)
//      — hash is built from the disc system area + boot executable bytes,
//      not from the file contents.
//

import CRcheevos
import Foundation

public enum RcheevosHash {

    /// Compute the RetroAchievements hash for `filePath` by auto-detecting the
    /// console from file extension / contents — the same mechanism RetroArch
    /// uses when calling `rc_client_begin_identify_and_load_game` with
    /// `RC_CONSOLE_UNKNOWN`.
    ///
    /// Returns a 32-character lowercase MD5 string, or `nil` if rcheevos
    /// could not derive a hash (file missing, format unrecognised).
    public static func compute(filePath: String) -> String? {
        guard !filePath.isEmpty else { return nil }

        // rcheevos picks the console from the extension, and `.gcm` (a raw
        // GameCube disc image, same layout as `.iso`) isn't in its table, so it
        // fell back to a whole-file MD5 that never matches. Hash it as GameCube.
        // `.tgc` is not included: it has its own header before the disc image,
        // which rcheevos' GameCube hasher can't skip.
        if let consoleID = explicitConsoleID(forPathExtension: (filePath as NSString).pathExtension) {
            return compute(filePath: filePath, consoleID: consoleID)
        }

        var hash: String?
        filePath.withCString { cPath in
            var iterator = rc_hash_iterator_t()
            // `rc_hash_initialize_iterator` strdups the path internally; the
            // iterator owns its own copy until destroy.
            rc_hash_initialize_iterator(&iterator, cPath, nil, 0)
            defer { rc_hash_destroy_iterator(&iterator) }

            var buffer = [CChar](repeating: 0, count: 33)
            let success = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
                guard let base = ptr.baseAddress else { return 0 }
                return rc_hash_iterate(base, &iterator)
            }
            guard success != 0 else { return }

            let nullIdx = buffer.firstIndex(of: 0) ?? buffer.endIndex
            let bytes = buffer[..<nullIdx].map { UInt8(bitPattern: $0) }
            if let result = String(bytes: bytes, encoding: .utf8), !result.isEmpty {
                hash = result
            }
        }
        return hash
    }

    /// Extensions rcheevos' auto-detection doesn't map, hashed as a known console.
    static func explicitConsoleID(forPathExtension pathExtension: String) -> UInt32? {
        switch pathExtension.lowercased() {
        case "gcm": return UInt32(RC_CONSOLE_GAMECUBE)
        default: return nil
        }
    }

    /// Hash `filePath` as `consoleID`, skipping rcheevos' extension auto-detection.
    static func compute(filePath: String, consoleID: UInt32) -> String? {
        var buffer = [CChar](repeating: 0, count: 33)
        let success = filePath.withCString { cPath in
            buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
                guard let base = ptr.baseAddress else { return 0 }
                return rc_hash_generate_from_file(base, consoleID, cPath)
            }
        }
        guard success != 0 else { return nil }
        let nullIdx = buffer.firstIndex(of: 0) ?? buffer.endIndex
        let result = String(bytes: buffer[..<nullIdx].map { UInt8(bitPattern: $0) }, encoding: .utf8)
        return result?.isEmpty == false ? result : nil
    }
}
