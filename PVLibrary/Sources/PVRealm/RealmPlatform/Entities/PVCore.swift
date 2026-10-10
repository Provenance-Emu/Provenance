//
//  PVCore.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import os
import PVLogging
import PVPrimitives
import PVSystems

@objcMembers
public final class PVCore: RealmSwift.Object, Identifiable {
    @Persisted(primaryKey: true) public var identifier: String = ""
    @Persisted public var principleClass: String = ""
    @Persisted public var supportedSystems: List<PVSystem>

    @Persisted public var projectName = ""
    @Persisted public var projectURL = ""
    @Persisted public var projectVersion = ""
    @Persisted public var disabled = false
    @Persisted public var appStoreDisabled = false
    @Persisted public var contentless = false

    /// Stored as display-name strings for Realm/ObjC compatibility.
    @Persisted public var supportedCheatTypeNames: List<String>

    /// Type-safe Swift accessor for the supported cheat code formats.
    public var supportedCheatTypes: [CheatCodeTypes] {
        supportedCheatTypeNames.compactMap { CheatCodeTypes(string: $0) }
    }

    /// SPDX license identifier (e.g. `"GPL-2.0-only"`, `"MIT"`). `nil` if not specified.
    @Persisted public var licenseName: String?
    /// URL pointing to the full license text. `nil` if not specified.
    @Persisted public var licenseURL: String?
    /// Copyright statement(s) for this core. `nil` if not specified.
    @Persisted public var copyright: String?

    public var hasCoreClass: Bool {
        if let _class: AnyClass = NSClassFromString(principleClass) {
            DLOG("Class: \(String(describing: _class)) for \(principleClass)")
            return true
        }
        // RetroArch-family principle classes (kept in Core.plist as registry keys) have no
        // class of their own: PVCoreFactory instantiates PVThinLibretroCore for them. Such a
        // core is available when its libretro dylib is bundled — Lite builds register the
        // whole RetroArch core list but ship no dylibs.
        if principleClass.contains("RetroArch") || principleClass.contains("LibRetro") || principleClass == "PVRetroArchCoreBridge" {
            let bundled = Self.isBundledLibretroCore(identifier)
            DLOG("Class: \(principleClass) not loaded — \(identifier) \(bundled ? "available via PVThinLibretroCore" : "has no bundled dylib")")
            return bundled
        }
        DLOG("Class: nil for \(principleClass)")
        return false
    }

    // Reverse links
    @Persisted(originProperty: "core") public var saveStates: LinkingObjects<PVSaveState>

    public convenience init(
        withIdentifier identifier: String,
        principleClass: String,
        supportedSystems: [PVSystem],
        name: String,
        url: String,
        version: String,
        disabled: Bool = false,
        appStoreDisabled: Bool = false,
        contentless: Bool = false,
        supportedCheatTypes: [CheatCodeTypes] = [],
        licenseName: String? = nil,
        licenseURL: String? = nil,
        copyright: String? = nil
    ) {
        self.init()
        self.identifier = identifier
        self.principleClass = principleClass
        self.supportedSystems.removeAll()
        self.supportedSystems.append(objectsIn: supportedSystems)
        projectName = name
        projectURL = url
        projectVersion = version
        self.disabled = disabled
        self.appStoreDisabled = appStoreDisabled
        self.contentless = contentless
        self.supportedCheatTypeNames.removeAll()
        self.supportedCheatTypeNames.append(objectsIn: supportedCheatTypes.map { $0.stringValue })
        self.licenseName = licenseName
        self.licenseURL = licenseURL
        self.copyright = copyright
    }

    public override class func ignoredProperties() -> [String] {
        ["hasCoreClass", "id", "supportedCheatTypes"]
    }

    public var id: String {
        return identifier
    }
}

// MARK: - Retired cores

/// Identifiers of native cores removed from the app (`PVCoreIdentifier` in each Core.plist), and of
/// the libretro cores that replace them (CoresRetro/RetroArch/Core.plist). Kept so records naming
/// the old cores can still be found and moved.
public enum RetiredCoreID {
    public static let jaguar = "com.provenance.core.jaguar"
    public static let atari800 = "com.provenance.core.atari800"
    public static let bliss = "com.provenance.core.bliss"
    public static let crabEMU = "com.provenance.core.crabemu"
    public static let gambatte = "com.provenance.core.gambatte"
    public static let odyssey2 = "com.provenance.core.odyssey2"
    public static let pokeMini = "com.provenance.core.pokemini"
    public static let visualBoyAdvance = "com.provenance.core.visualboyadvance"
    public static let desmume2015 = "com.provenance.core.desmume2015"
    public static let melonDS = "com.provenance.core.MelonDS"
    public static let beetlePSX = "com.provenance.core.beetlepsx"
    public static let freeIntv = "com.provenance.core.FreeIntv"
    public static let gme = "com.provenance.core.GME"
    public static let gearcoleco = "com.provenance.core.gearcoleco"
    public static let mu = "com.provenance.core.Mu"
    public static let mupen64PlusNX = "com.provenance.core.mupen64plusnx"
    public static let potator = "com.provenance.core.potator"
    public static let miniVMac = "com.provenance.core.minivmac"
    public static let yabause = "com.provenance.core.Yabause"
    public static let pcsxRearmed = "com.provenance.core.PCSXRearmed"
    public static let fuse = "com.provenance.core.Fuse"
    public static let opera = "com.provenance.core.opera"
}

public enum LibretroCoreID {
    public static let virtualJaguar = "virtualjaguar.libretro.framework"
    public static let atari800 = "atari800.libretro.framework"
    public static let a5200 = "a5200.libretro.framework"
    public static let freeIntv = "freeintv.libretro.framework"
    public static let genesisPlusGX = "genesis.plus.gx.libretro.framework"
    public static let gearcoleco = "gearcoleco.libretro.framework"
    public static let gambatte = "gambatte.libretro.framework"
    public static let o2em = "o2em.libretro.framework"
    public static let pokeMini = "pokemini.libretro.framework"
    public static let vbam = "vbam.libretro.framework"
    public static let desmume = "desmume.libretro.framework"
    public static let melonDS = "melonds.libretro.framework"
    public static let mednafenPSXHW = "mednafen.psx.hw.libretro.framework"
    public static let gme = "gme.libretro.framework"
    public static let mu = "mu.libretro.framework"
    public static let mupen64PlusNext = "mupen64plus.next.libretro.framework"
    public static let potator = "potator.libretro.framework"
    public static let miniVMac = "minivmac.libretro.framework"
    public static let yabause = "yabause.libretro.framework"
    public static let pcsxRearmed = "pcsx.rearmed.libretro.framework"
    public static let fuse = "fuse.libretro.framework"
    public static let opera = "opera.libretro.framework"
}

/// Where a retired core kept a battery save, and how its replacement gets it.
/// The thin wrapper reads `Battery States/<rom>/<rom>.srm` (RETRO_MEMORY_SAVE_RAM).
public struct RetiredBatterySaveRule: Equatable, Sendable {
    public enum Location: Equatable, Sendable {
        /// `Battery States/<rom>/`: the core's `batterySavesPath`.
        case batterySaves
        /// `Save States/<rom>/`: the legacy libretro bridge answered GET_SAVE_DIRECTORY with it.
        case saveStates
    }

    public let location: Location
    /// Extension of `<rom>.<ext>`, the file the retired core wrote.
    public let fileExtension: String
    /// Move the file into `Battery States/<rom>/` (for `.saveStates`).
    public let moveToBatterySaves: Bool
    /// Copy it to `Battery States/<rom>/<rom>.srm` when that file doesn't exist yet.
    public let copyToSRM: Bool

    public init(location: Location, fileExtension: String, moveToBatterySaves: Bool = false, copyToSRM: Bool = false) {
        self.location = location
        self.fileExtension = fileExtension
        self.moveToBatterySaves = moveToBatterySaves
        self.copyToSRM = copyToSRM
    }

    /// A raw battery file in Battery States, copied to the thin wrapper's `.srm`.
    public static func copiedToSRM(_ fileExtension: String) -> RetiredBatterySaveRule {
        RetiredBatterySaveRule(location: .batterySaves, fileExtension: fileExtension, copyToSRM: true)
    }

    /// A file the legacy bridge left in Save States, moved to Battery States.
    public static func movedFromSaveStates(_ fileExtension: String, copyToSRM: Bool = false) -> RetiredBatterySaveRule {
        RetiredBatterySaveRule(location: .saveStates, fileExtension: fileExtension, moveToBatterySaves: true, copyToSRM: copyToSRM)
    }
}

/// A native core removed from the app and the libretro core(s) that now run its games.
public struct RetiredCore: Equatable, Sendable {
    public let replacement: String
    /// Systems whose games go to a different replacement than `replacement`.
    public let systemReplacements: [SystemIdentifier: String]
    /// Save states load in the replacement (same emulator code). When false they keep the
    /// retired core, whose disabled row is never pruned.
    public let migratesSaveStates: Bool
    public let batterySaves: [RetiredBatterySaveRule]

    public init(replacement: String, systemReplacements: [SystemIdentifier: String] = [:],
                migratesSaveStates: Bool = false, batterySaves: [RetiredBatterySaveRule] = []) {
        self.replacement = replacement
        self.systemReplacements = systemReplacements
        self.migratesSaveStates = migratesSaveStates
        self.batterySaves = batterySaves
    }

    public func replacement(forSystem systemIdentifier: String?) -> String {
        guard let system = systemIdentifier.flatMap(SystemIdentifier.init(rawValue:)),
              let override = systemReplacements[system] else { return replacement }
        return override
    }

    public var allReplacements: [String] { [replacement] + systemReplacements.values.sorted() }
}

public extension PVCore {
    /// Cores removed from the app. See RetiredCoreMigration and RetiredBatterySaveMigration.
    static let retiredCores: [String: RetiredCore] = [
        // Native PVJaguar ran the same virtualjaguar libretro.c as the dylib,
        // so its save states load there (the core reads older state versions).
        RetiredCoreID.jaguar: RetiredCore(replacement: LibretroCoreID.virtualJaguar, migratesSaveStates: true),

        // Save-check cores (docs/superpowers/specs/2026-10-10-core-audit.md). Native save
        // states don't load in the dylibs; battery files are copied to the thin .srm.
        RetiredCoreID.atari800: RetiredCore(replacement: LibretroCoreID.atari800,
                                            systemReplacements: [.Atari5200: LibretroCoreID.a5200]),
        RetiredCoreID.bliss: RetiredCore(replacement: LibretroCoreID.freeIntv),
        RetiredCoreID.crabEMU: RetiredCore(replacement: LibretroCoreID.genesisPlusGX,
                                           systemReplacements: [.ColecoVision: LibretroCoreID.gearcoleco],
                                           batterySaves: [.copiedToSRM("sav")]),
        RetiredCoreID.gambatte: RetiredCore(replacement: LibretroCoreID.gambatte, batterySaves: [.copiedToSRM("sav")]),
        RetiredCoreID.odyssey2: RetiredCore(replacement: LibretroCoreID.o2em),
        RetiredCoreID.pokeMini: RetiredCore(replacement: LibretroCoreID.pokeMini, batterySaves: [.copiedToSRM("eep")]),
        RetiredCoreID.visualBoyAdvance: RetiredCore(replacement: LibretroCoreID.vbam, batterySaves: [.copiedToSRM("sav2")]),

        // Native DS (PVDisabled): the legacy bridge stored battery files in Save States.
        RetiredCoreID.desmume2015: RetiredCore(replacement: LibretroCoreID.desmume,
                                               batterySaves: [.movedFromSaveStates("dsv"), .movedFromSaveStates("sav")]),
        RetiredCoreID.melonDS: RetiredCore(replacement: LibretroCoreID.melonDS,
                                           batterySaves: [.movedFromSaveStates("sav", copyToSRM: true)]),

        // Legacy PVLibRetroCoreBridge shells: the bridge never persisted SAVE_RAM, so there
        // are no battery files to carry.
        RetiredCoreID.beetlePSX: RetiredCore(replacement: LibretroCoreID.mednafenPSXHW),
        RetiredCoreID.freeIntv: RetiredCore(replacement: LibretroCoreID.freeIntv),
        RetiredCoreID.gme: RetiredCore(replacement: LibretroCoreID.gme),
        RetiredCoreID.gearcoleco: RetiredCore(replacement: LibretroCoreID.gearcoleco),
        RetiredCoreID.mu: RetiredCore(replacement: LibretroCoreID.mu),
        RetiredCoreID.potator: RetiredCore(replacement: LibretroCoreID.potator),
        RetiredCoreID.miniVMac: RetiredCore(replacement: LibretroCoreID.miniVMac),
        RetiredCoreID.yabause: RetiredCore(replacement: LibretroCoreID.yabause),
        RetiredCoreID.pcsxRearmed: RetiredCore(replacement: LibretroCoreID.pcsxRearmed),
        RetiredCoreID.fuse: RetiredCore(replacement: LibretroCoreID.fuse),
        RetiredCoreID.opera: RetiredCore(replacement: LibretroCoreID.opera),
        // Per-type mupen battery files don't match mupen64plus_next's combined SAVE_RAM.
        RetiredCoreID.mupen64PlusNX: RetiredCore(replacement: LibretroCoreID.mupen64PlusNext),
    ]

    /// Retired core → its default replacement.
    static var retiredCoreReplacements: [String: String] { retiredCores.mapValues(\.replacement) }

    /// The retirements in effect in this build: those whose replacements are all
    /// bundled. Lite builds ship no libretro dylibs and keep the old core.
    static let activeRetiredCores: [String: RetiredCore] =
        retiredCores.filter { $0.value.allReplacements.allSatisfy(isBundledLibretroCore) }

    static let activeRetiredCoreReplacements: [String: String] = activeRetiredCores.mapValues(\.replacement)

    /// The identifier of the core that now loads `identifier`'s save states. Records arriving
    /// from iCloud, another device or an export still name the old core, so save-state lookups
    /// go through this. Only retirements whose save states migrate are remapped.
    static func currentIdentifier(for identifier: String) -> String {
        currentIdentifier(for: identifier, in: activeRetiredCores)
    }

    static func currentIdentifier(for identifier: String, in cores: [String: RetiredCore]) -> String {
        guard let retired = cores[identifier], retired.migratesSaveStates else { return identifier }
        return retired.replacement
    }

    /// Whether the app bundle contains the libretro core `identifier`
    /// (`<name>.libretro.framework` in its Frameworks folder).
    static func isBundledLibretroCore(_ identifier: String) -> Bool {
        guard identifier.hasSuffix(".libretro.framework") else { return false }
        // The bundle doesn't change while the app runs, and `hasCoreClass` (which
        // calls this) runs inside core-picker filters.
        if let cached = bundledLibretroCoreCache.withLock({ $0[identifier] }) {
            return cached
        }
        let bases = [Bundle.main.privateFrameworksURL,
                     Bundle.main.bundleURL.appendingPathComponent("Frameworks", isDirectory: true)]
        let bundled = bases.compactMap { $0 }.contains {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent(identifier, isDirectory: true).path)
        }
        bundledLibretroCoreCache.withLock { $0[identifier] = bundled }
        return bundled
    }

    private static let bundledLibretroCoreCache = OSAllocatedUnfairLock<[String: Bool]>(initialState: [:])
}
