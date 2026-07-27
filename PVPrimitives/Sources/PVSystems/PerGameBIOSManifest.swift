//
//  PerGameBIOSManifest.swift
//  PVPrimitives
//
//  Declarative description of BIOS files that are required by *individual
//  games* rather than by a whole system.
//
//  Provenance's `PVBIOS` model is per-system: BIOS records come from
//  `PVBIOSNames` in `systems.plist` and live at
//  `<docs>/BIOS/<systemIdentifier>/<filename>`.  That model cannot express
//  "House of the Dead 2 needs `hod2bios.zip`, but no other NAOMI title does" —
//  declaring it at the system level would make every NAOMI game refuse to
//  launch without it.
//
//  This manifest fills that gap.  It is a plain data resource
//  (`Resources/PerGameBIOS.json`) that maps a game — identified by its
//  ROM-set short name and/or MD5 — to the BIOS files that game specifically
//  needs.  Keeping it here (rather than in `systems.plist`) keeps arcade
//  ROM-set knowledge in one auditable, source-attributed place.
//

import Foundation
import PVLogging

// MARK: - Manifest DTO

/// A BIOS archive referenced by one or more per-game requirements.
///
/// `filenames` is an *any-of* list: the requirement is satisfied when **any**
/// of the listed names is present.  flycast, for example, probes
/// `<name>.zip` and then `<name>.7z`.
public struct PerGameBIOSFile: Codable, Sendable, Hashable {
    /// Stable identifier referenced by ``PerGameBIOSManifest/Group/Entry/bios``.
    public let id: String
    /// Accepted on-disk filenames, most-preferred first.
    public let filenames: [String]
    /// Human readable description shown in the BIOS UI and in error messages.
    public let description: String
    /// Expected MD5, or `nil` when unknown. Never guessed.
    public let md5: String?
    /// Expected size in bytes, or `nil` when unknown. Never guessed.
    public let size: Int?
    /// Raw `SystemIdentifier` whose BIOS folder this file belongs in.
    ///
    /// A group can cover several systems (the flycast arcade boards all share
    /// one rule set) but a `PVBIOS` record can only reference one system, and
    /// the importer uses that reference to decide where to file the download.
    /// This pins the answer instead of letting it fall out of group ordering.
    public let installSystem: String?

    /// The preferred filename to tell the user to install.
    public var canonicalFilename: String { filenames.first ?? id }

    public init(id: String,
                filenames: [String],
                description: String,
                md5: String? = nil,
                size: Int? = nil,
                installSystem: String? = nil) {
        self.id = id
        self.filenames = filenames
        self.description = description
        self.md5 = md5
        self.size = size
        self.installSystem = installSystem
    }
}

/// Root of the per-game BIOS manifest.
public struct PerGameBIOSManifest: Codable, Sendable, Hashable {

    /// A set of per-game rules that all apply to the same list of systems.
    public struct Group: Codable, Sendable, Hashable {

        /// One game → BIOS mapping.
        ///
        /// A game matches when *either* ``romSet`` equals the ROM's basename
        /// (see ``PerGameBIOSResolver/romSetName(fromFilename:)``) *or* ``md5``
        /// equals the ROM's MD5. Both comparisons are case-insensitive.
        public struct Entry: Codable, Sendable, Hashable {
            /// ROM-set short name, e.g. `"hotd2"`. Matched against the ROM
            /// filename with its final extension removed.
            public let romSet: String?
            /// ROM MD5, when known. `nil` in the shipped data — arcade ROM-set
            /// hashes are not sourced from the core's ROM table.
            public let md5: String?
            /// Display title, purely informational.
            public let title: String?
            /// IDs of the BIOS files this game needs, all of them.
            public let bios: [String]
            /// When `true` a missing file is reported but does not block launch.
            /// Defaults to `false`.
            public let optional: Bool?

            public init(romSet: String? = nil, md5: String? = nil, title: String? = nil, bios: [String], optional: Bool? = nil) {
                self.romSet = romSet
                self.md5 = md5
                self.title = title
                self.bios = bios
                self.optional = optional
            }
        }

        public let id: String
        public let description: String?
        /// Raw `SystemIdentifier` values this group applies to.
        public let systems: [String]
        /// Provenance of the data — file, commit and field it was transcribed from.
        public let source: String?
        public let entries: [Entry]

        public init(id: String, description: String? = nil, systems: [String], source: String? = nil, entries: [Entry]) {
            self.id = id
            self.description = description
            self.systems = systems
            self.source = source
            self.entries = entries
        }
    }

    /// Schema version. Bumped when the shape changes incompatibly.
    public let version: Int
    public let biosFiles: [PerGameBIOSFile]
    public let groups: [Group]

    public init(version: Int, biosFiles: [PerGameBIOSFile], groups: [Group]) {
        self.version = version
        self.biosFiles = biosFiles
        self.groups = groups
    }
}

public extension PerGameBIOSManifest {
    /// The only schema version this build understands.
    static let supportedVersion: Int = 1

    /// Decode a manifest from raw JSON.
    static func decode(from data: Data) throws -> PerGameBIOSManifest {
        try JSONDecoder().decode(PerGameBIOSManifest.self, from: data)
    }
}

// MARK: - Requirement

/// A single "this game needs this BIOS" requirement, resolved against the
/// manifest's ``PerGameBIOSFile`` table.
public struct PerGameBIOSRequirement: Sendable, Hashable, Identifiable {
    /// The BIOS file's manifest id, e.g. `"hod2bios"`.
    public let id: String
    /// Preferred filename to install, e.g. `"hod2bios.zip"`.
    public let canonicalFilename: String
    /// Every filename that satisfies this requirement (any-of).
    public let acceptedFilenames: [String]
    public let biosDescription: String
    public let expectedMD5: String?
    public let expectedSize: Int?
    /// When `true`, absence is informational rather than launch-blocking.
    public let optional: Bool
    /// Title of the game that triggered the requirement, when known.
    public let gameTitle: String?
    /// Raw `SystemIdentifier` whose BIOS folder this file belongs in, if pinned.
    public let installSystem: String?

    public init(id: String,
                canonicalFilename: String,
                acceptedFilenames: [String],
                biosDescription: String,
                expectedMD5: String? = nil,
                expectedSize: Int? = nil,
                optional: Bool = false,
                gameTitle: String? = nil,
                installSystem: String? = nil) {
        self.id = id
        self.canonicalFilename = canonicalFilename
        self.acceptedFilenames = acceptedFilenames
        self.biosDescription = biosDescription
        self.expectedMD5 = expectedMD5
        self.expectedSize = expectedSize
        self.optional = optional
        self.gameTitle = gameTitle
        self.installSystem = installSystem
    }

    /// Whether any accepted filename appears in `existingFilenames`.
    /// - Parameter existingFilenames: lowercased filenames found on disk.
    public func isSatisfied(byFilenames existingFilenames: Set<String>) -> Bool {
        acceptedFilenames.contains { existingFilenames.contains($0.lowercased()) }
    }
}

// MARK: - Errors

public enum PerGameBIOSManifestError: Error, Equatable, CustomStringConvertible {
    case unsupportedVersion(found: Int, supported: Int)
    case unknownBIOSID(String, inGroup: String)
    case duplicateBIOSID(String)
    case resourceNotFound

    public var description: String {
        switch self {
        case let .unsupportedVersion(found, supported):
            return "Unsupported per-game BIOS manifest version \(found) (expected \(supported))"
        case let .unknownBIOSID(id, group):
            return "Per-game BIOS manifest group '\(group)' references unknown BIOS id '\(id)'"
        case let .duplicateBIOSID(id):
            return "Per-game BIOS manifest declares BIOS id '\(id)' more than once"
        case .resourceNotFound:
            return "PerGameBIOS.json was not found in the PVSystems bundle"
        }
    }
}

// MARK: - Resolver

/// Indexed, query-ready view over a ``PerGameBIOSManifest``.
///
/// Construction validates the manifest (version, BIOS-id references) and builds
/// lookup tables, so resolution is a dictionary hit rather than a linear scan.
public struct PerGameBIOSResolver: Sendable {

    private struct Key: Hashable, Sendable {
        let system: String
        let value: String
    }

    public let manifest: PerGameBIOSManifest

    private let biosByID: [String: PerGameBIOSFile]
    private let byRomSet: [Key: [PerGameBIOSManifest.Group.Entry]]
    private let byMD5: [Key: [PerGameBIOSManifest.Group.Entry]]

    /// A resolver with no rules. Used as the failure fallback so a broken or
    /// missing manifest can never block a game launch.
    public static let empty = PerGameBIOSResolver()

    private init() {
        self.manifest = PerGameBIOSManifest(version: PerGameBIOSManifest.supportedVersion,
                                            biosFiles: [],
                                            groups: [])
        self.biosByID = [:]
        self.byRomSet = [:]
        self.byMD5 = [:]
    }

    public init(manifest: PerGameBIOSManifest) throws {
        guard manifest.version == PerGameBIOSManifest.supportedVersion else {
            throw PerGameBIOSManifestError.unsupportedVersion(found: manifest.version,
                                                              supported: PerGameBIOSManifest.supportedVersion)
        }

        var files = [String: PerGameBIOSFile]()
        for file in manifest.biosFiles {
            guard files[file.id] == nil else {
                throw PerGameBIOSManifestError.duplicateBIOSID(file.id)
            }
            files[file.id] = file
        }

        var romSetIndex = [Key: [PerGameBIOSManifest.Group.Entry]]()
        var md5Index = [Key: [PerGameBIOSManifest.Group.Entry]]()

        for group in manifest.groups {
            for entry in group.entries {
                for biosID in entry.bios where files[biosID] == nil {
                    throw PerGameBIOSManifestError.unknownBIOSID(biosID, inGroup: group.id)
                }
                for system in group.systems {
                    let system = system.lowercased()
                    if let romSet = entry.romSet, !romSet.isEmpty {
                        romSetIndex[Key(system: system, value: romSet.lowercased()), default: []].append(entry)
                    }
                    if let md5 = entry.md5, !md5.isEmpty {
                        md5Index[Key(system: system, value: md5.lowercased()), default: []].append(entry)
                    }
                }
            }
        }

        self.manifest = manifest
        self.biosByID = files
        self.byRomSet = romSetIndex
        self.byMD5 = md5Index
    }

    /// Decode and index a manifest from raw JSON.
    public init(data: Data) throws {
        try self.init(manifest: PerGameBIOSManifest.decode(from: data))
    }
}

// MARK: - Bundled resource

public extension PerGameBIOSResolver {
    /// Filename of the bundled manifest resource.
    static let resourceName = "PerGameBIOS"
    static let resourceExtension = "json"

    /// The `PVSystems` resource bundle that carries `PerGameBIOS.json`.
    ///
    /// Exposed because `Bundle.module` is internal to the module and so cannot
    /// be used as a default argument value.
    static var resourceBundle: Bundle { .module }

    /// Load the manifest shipped inside the `PVSystems` resource bundle.
    static func loadBundled(from bundle: Bundle? = nil) throws -> PerGameBIOSResolver {
        let bundle = bundle ?? resourceBundle
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw PerGameBIOSManifestError.resourceNotFound
        }
        return try PerGameBIOSResolver(data: Data(contentsOf: url))
    }

    /// The shipped manifest, or ``empty`` when it cannot be read.
    ///
    /// Falling back to ``empty`` is deliberate: a malformed manifest must
    /// degrade to "no per-game BIOS is required" rather than break launching.
    /// Logged loudly, because the symptom of a missing resource bundle is
    /// "the per-game BIOS gate silently does nothing" — indistinguishable from
    /// "no game needed one".
    static let bundled: PerGameBIOSResolver = {
        do {
            return try loadBundled()
        } catch {
            ELOG("PerGameBIOS: manifest unavailable, per-game BIOS checks disabled — \(error)")
            return .empty
        }
    }()
}

// MARK: - Resolution

public extension PerGameBIOSResolver {

    /// Derive the ROM-set short name from a ROM filename.
    ///
    /// Mirrors flycast's `get_file_basename` (core/stdclass.h): drop any
    /// directory component, then strip everything from the **last** `.`.
    /// Using the same rule means our lookup key and the core's lookup key
    /// always agree.
    static func romSetName(fromFilename filename: String) -> String {
        let base = (filename as NSString).lastPathComponent
        guard let dot = base.lastIndex(of: "."), dot != base.startIndex else { return base }
        return String(base[base.startIndex..<dot])
    }

    /// Requirements for a game, in manifest order, de-duplicated by BIOS id.
    ///
    /// - Parameters:
    ///   - systemIdentifier: raw `SystemIdentifier` value of the game's system.
    ///   - romFilename: the ROM's filename (extension optional).
    ///   - md5: the ROM's MD5, when known.
    func requirements(systemIdentifier: String,
                      romFilename: String?,
                      md5: String? = nil) -> [PerGameBIOSRequirement] {
        let system = systemIdentifier.lowercased()
        var matched = [PerGameBIOSManifest.Group.Entry]()

        if let romFilename, !romFilename.isEmpty {
            let romSet = Self.romSetName(fromFilename: romFilename).lowercased()
            matched += byRomSet[Key(system: system, value: romSet)] ?? []
        }
        if let md5, !md5.isEmpty {
            matched += byMD5[Key(system: system, value: md5.lowercased())] ?? []
        }
        guard !matched.isEmpty else { return [] }

        var seen = Set<String>()
        var result = [PerGameBIOSRequirement]()
        for entry in matched {
            for biosID in entry.bios {
                guard let file = biosByID[biosID], seen.insert(biosID).inserted else { continue }
                result.append(PerGameBIOSRequirement(id: file.id,
                                                     canonicalFilename: file.canonicalFilename,
                                                     acceptedFilenames: file.filenames,
                                                     biosDescription: file.description,
                                                     expectedMD5: file.md5,
                                                     expectedSize: file.size,
                                                     optional: entry.optional ?? false,
                                                     gameTitle: entry.title,
                                                     installSystem: file.installSystem))
            }
        }
        return result
    }

    /// Convenience overload taking a typed ``SystemIdentifier``.
    func requirements(system: SystemIdentifier,
                      romFilename: String?,
                      md5: String? = nil) -> [PerGameBIOSRequirement] {
        requirements(systemIdentifier: system.rawValue, romFilename: romFilename, md5: md5)
    }

    /// Requirements from ``requirements(systemIdentifier:romFilename:md5:)``
    /// that are not satisfied by any file in `existingFilenames`.
    ///
    /// - Parameter existingFilenames: filenames present in every directory the
    ///   core searches. Case is normalised internally.
    func missingRequirements(systemIdentifier: String,
                             romFilename: String?,
                             md5: String? = nil,
                             existingFilenames: Set<String>) -> [PerGameBIOSRequirement] {
        let normalized = Set(existingFilenames.map { $0.lowercased() })
        return requirements(systemIdentifier: systemIdentifier, romFilename: romFilename, md5: md5)
            .filter { !$0.isSatisfied(byFilenames: normalized) }
    }

    /// BIOS files that should be filed under `systemIdentifier`'s BIOS folder.
    ///
    /// Used to register per-game BIOS files with the library so the importer
    /// routes them into the right folder and the BIOS UI can list them.
    ///
    /// A file with an explicit ``PerGameBIOSFile/installSystem`` belongs to that
    /// system and no other, even though its *rules* may cover several systems.
    /// A file without one falls back to "any system a rule for it covers".
    func biosFiles(forSystemIdentifier systemIdentifier: String) -> [PerGameBIOSFile] {
        let system = systemIdentifier.lowercased()
        var seen = Set<String>()
        var result = [PerGameBIOSFile]()
        for group in manifest.groups where group.systems.contains(where: { $0.lowercased() == system }) {
            for entry in group.entries {
                for biosID in entry.bios {
                    guard let file = biosByID[biosID], !seen.contains(biosID) else { continue }
                    if let installSystem = file.installSystem, installSystem.lowercased() != system { continue }
                    seen.insert(biosID)
                    result.append(file)
                }
            }
        }
        return result
    }

    /// Raw system identifiers that have at least one per-game rule.
    var coveredSystemIdentifiers: [String] {
        var seen = Set<String>()
        var result = [String]()
        for group in manifest.groups {
            for system in group.systems where seen.insert(system).inserted {
                result.append(system)
            }
        }
        return result
    }
}
