//
//  ArchiveContentClassifier.swift
//  PVArchiving
//
//  Created on 8/8/26.
//

import Foundation

/// Decides whether an archive's *contents* identify it as an optical-disc
/// bundle rather than an arcade ROM set.
///
/// Importers use this to tell apart two things that can share an outer
/// filename: a Dreamcast arcade port (`Crazy Taxi.zip` holding
/// `Crazy Taxi.cdi`) and the MAME romset of the same game. Only the entries
/// inside can separate them.
///
/// ## Why this is not derived from a generic "disc extensions" list
///
/// It used to be. The caller composed its rejection set from every known
/// disc-ish extension plus `bin`, on the stated assumption that "MAME / CPS
/// ROMs are always chip dumps, never optical-disc images". The assumption is
/// true; the inference from it was not — **arcade chip dumps are routinely
/// named `.bin`**. `dkong.zip` is `c_5et_g.bin`, `c_5ct_g.bin`, `v_5h_b.bin`
/// and friends. Every such romset was classified as a CD bundle and extracted,
/// which destroys it: MAME accepts only `zip`/`cmd`/`chd`/`7z`, so the loose
/// members cannot be re-imported.
///
/// So the set here is deliberately hand-picked for *this* judgement instead of
/// derived from a broader enum. `bin` and `img` are generic names that carry no
/// format information, and are treated as evidence only via ``binaryDiscImageSizeThreshold``.
/// When adding a new disc format elsewhere in the codebase, consider whether it
/// belongs in ``decisiveOpticalExtensions`` too.
public enum ArchiveContentClassifier {

    /// Extensions that identify optical media on sight. None of these ever
    /// appear inside an arcade ROM set, so a single hit is conclusive.
    ///
    /// Includes descriptors (`cue`, `gdi`, `ccd`, `toc`, `m3u`) as well as
    /// image formats: a descriptor is what turns a pile of `.bin` tracks into
    /// a disc, so its presence settles the ambiguous case on its own.
    public static let decisiveOpticalExtensions: Set<String> = [
        // Image formats
        "cdi", "gdi", "iso", "chd", "ccd", "nrg", "mds", "pbp", "cso", "ecm",
        // Descriptors / playlists
        "cue", "m3u", "toc"
    ]

    /// Extensions too generic to judge by name. A disc image and an arcade chip
    /// dump can both be `.bin`; only size separates them when no descriptor is
    /// present alongside.
    ///
    /// `img` is here by symmetry rather than by demonstrated failure — it is as
    /// format-free a name as `bin`. Demoting it from "decisive" does widen what
    /// reaches the caller, but harmlessly: `shouldKeepArchiveAsIs` still requires
    /// a libretro-DB arcade match before keeping an archive intact, so a small
    /// `.img` zip that is not a romset is extracted either way.
    public static let ambiguousBinaryExtensions: Set<String> = ["bin", "img"]

    /// Size above which a bare ``ambiguousBinaryExtensions`` entry is read as a
    /// disc image rather than a chip dump.
    ///
    /// Arcade mask ROMs top out well below this — the largest single dumps in
    /// the sets handled here (NeoGeo V-ROMs, CPS3 SIMMs) are around 8 MB. A
    /// descriptor-less disc image is orders of magnitude larger.
    ///
    /// The threshold is biased deliberately. A descriptor-less disc image under
    /// 64 MB (a small homebrew or demo disc) is read as "not a disc" and merely
    /// takes an extra extraction pass; the opposite error destroys a romset.
    public static let binaryDiscImageSizeThreshold: Int64 = 64 * 1024 * 1024

    /// Whether these archive entries describe an optical disc.
    ///
    /// - Parameter entries: The archive's contents. Directory entries are ignored.
    /// - Returns: `true` when a decisive optical extension is present, or when
    ///   an ambiguous binary entry is large enough to only make sense as a disc
    ///   image. Entries with an unknown size are never assumed to be large —
    ///   guessing in that direction is what corrupted romsets before.
    public static func looksLikeOpticalDiscBundle(entries: [ArchiveEntryInfo]) -> Bool {
        entries.contains { entry in
            guard !entry.isDirectory else { return false }
            let ext = (entry.name as NSString).pathExtension.lowercased()

            if decisiveOpticalExtensions.contains(ext) {
                return true
            }
            if ambiguousBinaryExtensions.contains(ext), let size = entry.size {
                return size > binaryDiscImageSizeThreshold
            }
            return false
        }
    }
}
