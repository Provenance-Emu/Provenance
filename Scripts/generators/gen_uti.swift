#!/usr/bin/env swift
// gen_uti.swift - Generate UTI declarations and update Info.plist files

import Foundation

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let systemsPlist = repoRoot.appendingPathComponent("PVLibrary/Sources/PVLibrary/Resources/systems.plist")
let referenceURL = "https://provenance-emu.com/"
let mimeBase = "application/x-provenance-"

// SYSTEM_UTI_MAP: system identifier -> (suffix, display name)
let systemUTIMap: [String: (String, String)] = [
    "com.provenance.2600":         ("atari2600",    "Atari 2600"),
    "com.provenance.5200":         ("atari5200",    "Atari 5200"),
    "com.provenance.7800":         ("atari7800",    "Atari 7800"),
    "com.provenance.lynx":         ("lynx",         "Atari Lynx"),
    "com.provenance.jaguar":       ("jaguar",       "Atari Jaguar"),
    "com.provenance.jaguarcd":     ("jaguarcd",     "Atari Jaguar CD"),
    "com.provenance.atarist":      ("atarist",      "Atari ST"),
    "com.provenance.atari8bit":    ("atari8bit",    "Atari 8-bit"),
    "com.provenance.nes":          ("nes",          "Nintendo Entertainment System"),
    "com.provenance.fds":          ("fds",          "Famicom Disk System"),
    "com.provenance.snes":         ("snes",         "Super Nintendo"),
    "com.provenance.gb":           ("gb",           "Game Boy"),
    "com.provenance.gbc":          ("gbc",          "Game Boy Color"),
    "com.provenance.gba":          ("gba",          "Game Boy Advance"),
    "com.provenance.n64":          ("n64",          "Nintendo 64"),
    "com.provenance.ds":           ("ds",           "Nintendo DS"),
    "com.provenance.3ds":          ("3ds",          "Nintendo 3DS"),
    "com.provenance.gamecube":     ("gamecube",     "GameCube"),
    "com.provenance.wii":          ("wii",          "Wii"),
    "com.provenance.genesis":      ("genesis",      "Sega Genesis / Mega Drive"),
    "com.provenance.mastersystem": ("mastersystem", "Sega Master System"),
    "com.provenance.gamegear":     ("gamegear",     "Game Gear"),
    "com.provenance.32X":          ("sega32x",      "Sega 32X"),
    "com.provenance.segacd":       ("segacd",       "Sega CD"),
    "com.provenance.saturn":       ("saturn",       "Sega Saturn"),
    "com.provenance.dreamcast":    ("dreamcast",    "Dreamcast"),
    "com.provenance.naomi":        ("naomi",        "NAOMI"),
    "com.provenance.naomi2":       ("naomi2",       "NAOMI 2"),
    "com.provenance.atomiswave":   ("atomiswave",   "Atomiswave"),
    "com.provenance.sg1000":       ("sg1000",       "SG-1000"),
    "com.provenance.psx":          ("psx",          "PlayStation"),
    "com.provenance.ps2":          ("ps2",          "PlayStation 2"),
    "com.provenance.ps3":          ("ps3",          "PlayStation 3"),
    "com.provenance.psp":          ("psp",          "PlayStation Portable"),
    "com.provenance.3DO":          ("3do",          "3DO"),
    "com.provenance.pce":          ("pce",          "TurboGrafx-16 / PC Engine"),
    "com.provenance.pcecd":        ("pcecd",        "TurboGrafx-CD"),
    "com.provenance.sgfx":         ("sgfx",         "SuperGrafx"),
    "com.provenance.pcfx":         ("pcfx",         "PC-FX"),
    "com.provenance.ngp":          ("ngp",          "Neo Geo Pocket"),
    "com.provenance.ngpc":         ("ngpc",         "Neo Geo Pocket Color"),
    "com.provenance.neogeo":       ("neogeo",       "Neo Geo"),
    "com.provenance.ws":           ("ws",           "WonderSwan"),
    "com.provenance.wsc":          ("wsc",          "WonderSwan Color"),
    "com.provenance.vb":           ("vb",           "Virtual Boy"),
    "com.provenance.pokemonmini":  ("pokemonmini",  "Pokemon mini"),
    "com.provenance.msx":          ("msx",          "MSX"),
    "com.provenance.msx2":         ("msx2",         "MSX2"),
    "com.provenance.colecovision": ("colecovision", "ColecoVision"),
    "com.provenance.intellivision":("intellivision","Intellivision"),
    "com.provenance.odyssey2":     ("odyssey2",     "Odyssey2 / Videopac"),
    "com.provenance.c64":          ("c64",          "Commodore 64"),
    "com.provenance.dos":          ("dos",          "DOS"),
    "com.provenance.macintosh":    ("macintosh",    "Classic Mac"),
    "com.provenance.appleII":      ("appleii",      "Apple II"),
    "com.provenance.ep128":        ("ep128",        "Enterprise 128"),
    "com.provenance.zxspectrum":   ("zxspectrum",   "ZX Spectrum"),
    "com.provenance.vectrex":      ("vectrex",      "Vectrex"),
    "com.provenance.supervision":  ("supervision",  "Supervision"),
    "com.provenance.tic80":        ("tic80",        "TIC-80"),
    "com.provenance.cdi":          ("cdi",          "Philips CD-i"),
    "com.provenance.palmos":       ("palmos",       "Palm OS"),
    "com.provenance.mame":         ("mame",         "MAME"),
    "com.provenance.cps1":         ("cps1",         "CPS-1"),
    "com.provenance.cps2":         ("cps2",         "CPS-2"),
    "com.provenance.cps3":         ("cps3",         "CPS-3"),
    "com.provenance.music":        ("music",        "Game Music"),
    "com.provenance.doom":         ("doom",         "Doom"),
    "com.provenance.quake":        ("quake",        "Quake"),
    "com.provenance.quake2":       ("quake2",       "Quake II"),
    "com.provenance.wolf3d":       ("wolf3d",       "Wolfenstein 3D"),
    "com.provenance.pc98":         ("pc98",         "NEC PC-98"),
    "com.provenance.retroarch":    ("retroarch",    "RetroArch"),
]

let archiveExts: Set<String> = ["7z", "rar", "zip", "iso"]

let baseRomExtensions: Set<String> = [
    "rom",
    "bin",
    "cue", "toc", "ccd",
    "chd",
    "m3u", "m3u8",
    "bios",
    "elf",
    "dol",
    "img",
    "mdf", "mds",
    "nrg",
    "ciso",
    "gcz",
    "rvz",   // GameCube/Wii compressed format — also in base so ThumbnailExtension handles it
    "isz",
    "gz",
    "lzh",
]

// Load systems.plist
guard let systemsData = FileManager.default.contents(atPath: systemsPlist.path),
      let systemsList = try? PropertyListSerialization.propertyList(from: systemsData, format: nil) as? [[String: Any]] else {
    print("ERROR: Could not load systems.plist")
    exit(1)
}

// Build system extension map
var systemExtMap: [String: [String]] = [:]
for system in systemsList {
    guard let sid = system["PVSystemIdentifier"] as? String,
          let exts = system["PVSupportedExtensions"] as? [String] else { continue }
    let lowerExts = Array(Set(exts.map { $0.lowercased() })).sorted()
    systemExtMap[sid] = lowerExts
}

// Generate per-system UTI entries
var systemClaimedExts: Set<String> = []
var perSystemEntries: [[String: Any]] = []

for sid in systemExtMap.keys.sorted() {
    guard let utiInfo = systemUTIMap[sid] else { continue }
    let (suffix, displayName) = utiInfo
    let utiID = "com.provenance.rom.\(suffix)"

    let sysExts = systemExtMap[sid] ?? []
    let systemSpecific = sysExts.filter { !archiveExts.contains($0) }

    for e in systemSpecific {
        systemClaimedExts.insert(e)
    }

    if !systemSpecific.isEmpty {
        let entry: [String: Any] = [
            "UTTypeConformsTo": ["com.provenance.rom"],
            "UTTypeDescription": "\(displayName) ROM",
            "UTTypeIconFiles": [] as [String],
            "UTTypeIdentifier": utiID,
            "UTTypeReferenceURL": referenceURL,
            "UTTypeTagSpecification": [
                "public.filename-extension": systemSpecific,
                "public.mime-type": ["\(mimeBase)\(suffix)-rom"],
            ] as [String: Any],
        ]
        perSystemEntries.append(entry)
    }
}

// Compute all system extensions
var allSystemExts: Set<String> = []
for exts in systemExtMap.values {
    for e in exts { allSystemExts.insert(e) }
}

// Base ROM extensions: explicit list + unclaimed system exts (no archives)
let unclaimed = allSystemExts.subtracting(systemClaimedExts).subtracting(archiveExts)
var baseExtSet = baseRomExtensions.union(unclaimed)

// Deduplicate case-insensitively
var seenLower: Set<String> = []
var baseExtsFinal: [String] = []
for e in baseExtSet.sorted(by: { $0.lowercased() < $1.lowercased() }) {
    let lo = e.lowercased()
    if !seenLower.contains(lo) {
        seenLower.insert(lo)
        baseExtsFinal.append(e)
    }
}
baseExtsFinal.sort { $0.lowercased() < $1.lowercased() }

let baseRomEntry: [String: Any] = [
    "UTTypeConformsTo": ["public.data"],
    "UTTypeDescription": "ROM file",
    "UTTypeIconFiles": [] as [String],
    "UTTypeIdentifier": "com.provenance.rom",
    "UTTypeReferenceURL": referenceURL,
    "UTTypeTagSpecification": [
        "public.filename-extension": baseExtsFinal,
        "public.mime-type": ["\(mimeBase)rom"],
    ] as [String: Any],
]

var exported: [[String: Any]] = [baseRomEntry]
exported.append(contentsOf: perSystemEntries)

// Save State
// .svs  = raw emulator save-state slot file (PVEmulatorViewController naming convention)
// .pvsav = Provenance Save State bundle (canonical extension per SpotlightImportExtension)
exported.append([
    "UTTypeConformsTo": ["public.data"],
    "UTTypeDescription": "Provenance Save State",
    "UTTypeIconFiles": [] as [String],
    "UTTypeIdentifier": "com.provenance.savestate",
    "UTTypeReferenceURL": referenceURL,
    "UTTypeTagSpecification": [
        "public.filename-extension": ["svs", "pvsav"],
        "public.mime-type": ["\(mimeBase)savestate"],
    ] as [String: Any],
])

// Cheat codes
exported.append([
    "UTTypeConformsTo": ["public.data"],
    "UTTypeDescription": "Provenance Cheat Code",
    "UTTypeIconFiles": [] as [String],
    "UTTypeIdentifier": "com.provenance.cheat",
    "UTTypeReferenceURL": referenceURL,
    "UTTypeTagSpecification": [
        "public.filename-extension": ["pvc"],
        "public.mime-type": ["\(mimeBase)cheat"],
    ] as [String: Any],
])

// Artwork
exported.append([
    "UTTypeConformsTo": ["public.image"],
    "UTTypeDescription": "Provenance Game Artwork",
    "UTTypeIconFiles": [] as [String],
    "UTTypeIdentifier": "com.provenance.artwork",
    "UTTypeReferenceURL": referenceURL,
    "UTTypeTagSpecification": [
        "public.filename-extension": ["gif", "jpeg", "jpg", "png", "webp"],
        "public.mime-type": ["image/jpeg"],
    ] as [String: Any],
])

// Imported archive types
let imported: [[String: Any]] = [
    [
        "UTTypeConformsTo": ["public.archive", "public.data"],
        "UTTypeDescription": "7-Zip Archive",
        "UTTypeIconFiles": [] as [String],
        "UTTypeIdentifier": "org.7-zip.7-zip-archive",
        "UTTypeReferenceURL": referenceURL,
        "UTTypeTagSpecification": ["public.filename-extension": ["7z"]] as [String: Any],
    ],
    [
        "UTTypeConformsTo": ["public.archive", "public.data"],
        "UTTypeDescription": "RAR Archive",
        "UTTypeIconFiles": [] as [String],
        "UTTypeIdentifier": "com.rarlab.rar-archive",
        "UTTypeReferenceURL": referenceURL,
        "UTTypeTagSpecification": ["public.filename-extension": ["rar"]] as [String: Any],
    ],
    [
        "UTTypeConformsTo": ["public.archive", "public.data"],
        "UTTypeDescription": "Zip Archive",
        "UTTypeIconFiles": [] as [String],
        "UTTypeIdentifier": "public.zip-archive",
        "UTTypeReferenceURL": referenceURL,
        "UTTypeTagSpecification": ["public.filename-extension": ["zip"]] as [String: Any],
    ],
    [
        "UTTypeConformsTo": ["public.disk-image", "public.data"],
        "UTTypeDescription": "ISO Disc Image",
        "UTTypeIconFiles": [] as [String],
        "UTTypeIdentifier": "public.iso-image",
        "UTTypeReferenceURL": referenceURL,
        "UTTypeTagSpecification": ["public.filename-extension": ["iso"]] as [String: Any],
    ],
]

// Build the ROM LSItemContentTypes: base + all per-system UTIs (explicit listing
// ensures correct UTI dispatch even when conformance inference is incomplete).
var romContentTypes: [String] = ["com.provenance.rom"]
for e in perSystemEntries {
    if let utiID = e["UTTypeIdentifier"] as? String {
        romContentTypes.append(utiID)
    }
}
romContentTypes += [
    "org.7-zip.7-zip-archive",
    "com.rarlab.rar-archive",
    "public.zip-archive",
    "public.iso-image",
]

let documentTypes: [[String: Any]] = [
    [
        "CFBundleTypeIconFiles": [] as [String],
        "CFBundleTypeName": "ROM",
        "LSHandlerRank": "Owner",
        "LSItemContentTypes": romContentTypes,
    ],
    [
        "CFBundleTypeIconFiles": [] as [String],
        "CFBundleTypeName": "Save State",
        "LSHandlerRank": "Owner",
        "LSItemContentTypes": ["com.provenance.savestate"],
    ],
    [
        "CFBundleTypeIconFiles": [] as [String],
        "CFBundleTypeName": "Artwork",
        "LSHandlerRank": "Alternate",
        "LSItemContentTypes": [
            "public.image",
            "public.jpeg",
            "public.png",
            "com.compuserve.gif",
        ],
    ],
]

// Print summary
print("\n=== UTI Generation Summary ===")
print("Exported types: \(exported.count)")
let romTypes = exported.filter { ($0["UTTypeIdentifier"] as? String ?? "").contains("rom") }
print("  ROM types (base + per-system): \(romTypes.count)")
var allExts: Set<String> = []
for e in exported {
    if let spec = e["UTTypeTagSpecification"] as? [String: Any],
       let exts = spec["public.filename-extension"] as? [String] {
        for ext in exts { allExts.insert(ext) }
    }
}
for i in imported {
    if let spec = i["UTTypeTagSpecification"] as? [String: Any],
       let exts = spec["public.filename-extension"] as? [String] {
        for ext in exts { allExts.insert(ext) }
    }
}
print("  Total extensions covered: \(allExts.count)")
print("Imported types: \(imported.count)")

print("\nPer-system types generated:")
for e in exported {
    guard let utiID = e["UTTypeIdentifier"] as? String, utiID.hasPrefix("com.provenance.rom."),
          let spec = e["UTTypeTagSpecification"] as? [String: Any],
          let exts = spec["public.filename-extension"] as? [String] else { continue }
    print("  \(utiID): \(exts)")
}

print("\nBase ROM extensions:")
if let spec = baseRomEntry["UTTypeTagSpecification"] as? [String: Any],
   let exts = spec["public.filename-extension"] as? [String] {
    print("  \(exts)")
}

// NOTE: The QuickLook extension Info.plists (Extensions/QuickLookPreview/Info.plist
// and Extensions/ThumbnailExtension/Info.plist) use a different structure
// (QLSupportedContentTypes under NSExtension > NSExtensionAttributes) and are NOT
// auto-updated by this script. After adding a new system to systemUTIMap, manually
// add the corresponding "com.provenance.rom.<suffix>" string to QLSupportedContentTypes
// in both extension plists to avoid thumbnail/preview gaps for new file types.

// Plists to fully replace UTI sections (standard builds)
let plistPaths = [
    "Provenance/Provenance-Info.plist",
    "Provenance/Provenance-Lite-Info.plist",
    "Provenance/Provenance-Lite (AppStore)-Info.plist",
    "Provenance/Provenance-UnderDevelopment-Info.plist",
    "ProvenanceTV/ProvenanceTV-AppStore-Info.plist",
    "ProvenanceTV/ProvenanceTV-Lite-Info.plist",
]

// Plists that need merge (preserve existing special UTExportedTypeDeclarations entries)
let plistPathsMerge = [
    "Provenance/Provenance-AppStore-Info.plist",
]

func updatePlist(_ plistURL: URL, exported: [[String: Any]], imported: [[String: Any]],
                 documentTypes: [[String: Any]], merge: Bool) throws {
    guard let data = FileManager.default.contents(atPath: plistURL.path),
          var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        throw NSError(domain: "GenUTI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not parse plist"])
    }

    if merge {
        // Preserve existing UTExportedTypeDeclarations entries that aren't ROM-related
        var existingExported = plist["UTExportedTypeDeclarations"] as? [[String: Any]] ?? []
        existingExported = existingExported.filter { entry in
            guard let id = entry["UTTypeIdentifier"] as? String else { return false }
            return !id.hasPrefix("com.provenance.rom") &&
                   !id.hasPrefix("com.provenance.savestate") &&
                   !id.hasPrefix("com.provenance.cheat") &&
                   !id.hasPrefix("com.provenance.artwork")
        }
        plist["UTExportedTypeDeclarations"] = existingExported + exported
        // Merge CFBundleDocumentTypes: prepend existing non-ROM types
        var existingDocTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        let romTypeNames = Set(["ROM", "Save State", "Artwork"])
        existingDocTypes = existingDocTypes.filter { entry in
            guard let name = entry["CFBundleTypeName"] as? String else { return true }
            return !romTypeNames.contains(name)
        }
        plist["CFBundleDocumentTypes"] = existingDocTypes + documentTypes
    } else {
        plist["UTExportedTypeDeclarations"] = exported
        plist["CFBundleDocumentTypes"] = documentTypes
    }
    plist["UTImportedTypeDeclarations"] = imported

    let outData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try outData.write(to: plistURL)
}

print("\nUpdating Info.plist files:")
for plistStr in plistPaths {
    let plistURL = repoRoot.appendingPathComponent(plistStr)
    guard FileManager.default.fileExists(atPath: plistURL.path) else {
        print("  WARNING: \(plistStr) not found, skipping")
        continue
    }
    do {
        try updatePlist(plistURL, exported: exported, imported: imported,
                        documentTypes: documentTypes, merge: false)
        print("  OK: \(plistStr)")
    } catch {
        print("  ERROR on \(plistStr): \(error)")
    }
}

print("Merging special Info.plist files (preserving extra entries):")
for plistStr in plistPathsMerge {
    let plistURL = repoRoot.appendingPathComponent(plistStr)
    guard FileManager.default.fileExists(atPath: plistURL.path) else {
        print("  WARNING: \(plistStr) not found, skipping")
        continue
    }
    do {
        try updatePlist(plistURL, exported: exported, imported: imported,
                        documentTypes: documentTypes, merge: true)
        print("  OK (merged): \(plistStr)")
    } catch {
        print("  ERROR on \(plistStr): \(error)")
    }
}

print("\nDone.")
