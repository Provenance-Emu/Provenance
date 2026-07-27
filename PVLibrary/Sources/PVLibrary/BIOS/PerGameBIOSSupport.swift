//
//  PerGameBIOSSupport.swift
//  PVLibrary
//
//  Library-side glue for the per-game BIOS manifest declared in
//  `PVSystems/PerGameBIOSManifest.swift`.
//
//  Responsibilities:
//   1. Work out which directories a core actually reads per-game BIOS from,
//      and which of the required files are present in any of them.
//   2. Register the manifest's BIOS files as `PVBIOS` records so the existing
//      machinery — importer routing, the BIOS status UI, CloudKit BIOS sync
//      and the thin wrapper's `_syncBIOSResources` copy step — picks them up
//      without any of those subsystems learning about the manifest.
//
//  Placement note: the records are seeded as *optional* on purpose. A per-game
//  BIOS must not gate every game on the system; enforcement happens per launch
//  via ``PerGameBIOS/missingRequirements(forSystemIdentifier:romFilename:md5:)``.
//

import Foundation
import PVLogging
import PVPrimitives
import PVSystems
import PVFileSystem
import PVRealm

public enum PerGameBIOS {

    /// The shipped manifest.
    public static var resolver: PerGameBIOSResolver { .bundled }

    // MARK: - Search paths

    /// Directories that count as "installed" for a per-game BIOS file.
    ///
    /// A file is considered present when it exists in **any** of these:
    ///
    /// 1. `<docs>/BIOS/<systemIdentifier>/` — where the importer, the BIOS UI
    ///    and CloudKit put BIOS files. The thin wrapper copies everything from
    ///    here into the core's system directory before `retro_load_game`
    ///    (`PVThinLibretroFrontend._syncBIOSResources`).
    /// 2. `<docs>/System/<systemDirectoryName>/` — the core's system directory.
    /// 3. `<docs>/System/<systemDirectoryName>/<retroArchSystemDirectoryName>/`
    ///    — the subdirectory the core actually scans. flycast resolves its
    ///    NAOMI BIOS with a single `file_exists` at `<system dir>/dc/<name>`
    ///    and has no fallback to the system-dir root.
    ///
    /// (2) and (3) matter because the system directory is shared by Dreamcast,
    /// NAOMI, NAOMI 2 and Atomiswave and is never pruned — a file synced there
    /// by an earlier launch is still found by the core, so treating it as
    /// missing would falsely block a working setup.
    ///
    /// A *sibling* system's BIOS directory is deliberately NOT searched: those
    /// are never synced for the game being launched, so a hit there would be a
    /// false pass.
    public static func searchDirectories(forSystemIdentifier systemID: String) -> [URL] {
        var directories: [URL] = [PVEmulatorConfiguration.biosPath(forSystemIdentifier: systemID)]

        if let system = SystemIdentifier(rawValue: systemID),
           let directoryName = system.systemDirectoryName {
            /// Build the URL by hand rather than via `Paths.systemPath(forSystemName:)`
            /// so that a read-only presence check never creates directories.
            let systemDirectory = Paths.systemPath.appendingPathComponent(directoryName, isDirectory: true)
            directories.append(systemDirectory)
            if let coreSubdirectory = system.retroArchSystemDirectoryName {
                directories.append(systemDirectory.appendingPathComponent(coreSubdirectory, isDirectory: true))
            }
        }
        return directories
    }

    /// Lowercased names of every file visible in ``searchDirectories(forSystemIdentifier:)``.
    public static func installedFilenames(forSystemIdentifier systemID: String) -> Set<String> {
        var found = Set<String>()
        let fileManager = FileManager.default
        for directory in searchDirectories(forSystemIdentifier: systemID) {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { continue }
            found.formUnion(contents.map { $0.lastPathComponent.lowercased() })
        }
        return found
    }

    // MARK: - Staging

    /// Copy a required per-game BIOS that is sitting in a *different* covered
    /// system's BIOS folder into the launching game's own BIOS folder.
    ///
    /// Needed because the four flycast systems each have their own
    /// `<docs>/BIOS/<systemIdentifier>/` folder while the manifest pins each
    /// BIOS archive to exactly one of them (``PerGameBIOSFile/installSystem``).
    /// A NAOMI 2 game whose `naomi2.zip` was filed under NAOMI — or a file the
    /// user dropped in by hand — would otherwise never reach the core, because
    /// the wrapper's sync step only reads the launching game's own BIOS folder.
    ///
    /// Only files this launch actually needs are copied, and existing files are
    /// never overwritten.
    /// - Returns: the number of files copied.
    @discardableResult
    public static func stage(_ requirements: [PerGameBIOSRequirement],
                             forSystemIdentifier systemID: String) -> Int {
        guard !requirements.isEmpty else { return 0 }

        let fileManager = FileManager.default
        let destination = PVEmulatorConfiguration.biosPath(forSystemIdentifier: systemID)

        /// Every other BIOS folder in the manifest's scope, plus the folder the
        /// manifest pins each requirement to.
        var sources = resolver.coveredSystemIdentifiers
        sources += requirements.compactMap(\.installSystem)
        let sourceDirectories = Set(sources.filter { $0.caseInsensitiveCompare(systemID) != .orderedSame })
            .map { PVEmulatorConfiguration.biosPath(forSystemIdentifier: $0) }
        guard !sourceDirectories.isEmpty else { return 0 }

        var copied = 0
        for requirement in requirements {
            for filename in requirement.acceptedFilenames {
                let target = destination.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: target.path) { continue }
                guard let source = sourceDirectories
                    .map({ $0.appendingPathComponent(filename) })
                    .first(where: { fileManager.fileExists(atPath: $0.path) }) else { continue }
                do {
                    try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                    try fileManager.copyItem(at: source, to: target)
                    copied += 1
                    ILOG("PerGameBIOS: staged \(filename) → BIOS/\(systemID)")
                } catch {
                    WLOG("PerGameBIOS: could not stage \(filename): \(error.localizedDescription)")
                }
            }
        }
        return copied
    }

    // MARK: - Resolution

    /// Per-game BIOS files this game needs that are not installed anywhere the
    /// core will look. Empty when the game has no per-game requirement.
    ///
    /// Stages any requirement found in a sibling system's BIOS folder first, so
    /// a merely-misfiled BIOS is fixed instead of reported as missing.
    public static func missingRequirements(forSystemIdentifier systemID: String,
                                           romFilename: String?,
                                           md5: String?) -> [PerGameBIOSRequirement] {
        let required = resolver.requirements(systemIdentifier: systemID, romFilename: romFilename, md5: md5)
        guard !required.isEmpty else { return [] }

        var installed = installedFilenames(forSystemIdentifier: systemID)
        let unsatisfied = required.filter { !$0.isSatisfied(byFilenames: installed) }
        guard !unsatisfied.isEmpty else { return [] }

        if stage(unsatisfied, forSystemIdentifier: systemID) > 0 {
            installed = installedFilenames(forSystemIdentifier: systemID)
        }
        return unsatisfied.filter { !$0.isSatisfied(byFilenames: installed) }
    }

    /// Convenience overload for a Realm `PVGame`.
    ///
    /// Reads `romPath` rather than the `PVFile` so this stays cheap and does
    /// not touch the file system for the name.
    public static func missingRequirements(forGame game: PVGame) -> [PerGameBIOSRequirement] {
        guard !game.isInvalidated else { return [] }
        let systemID = game.systemIdentifier
        guard !systemID.isEmpty else { return [] }
        return missingRequirements(forSystemIdentifier: systemID,
                                   romFilename: game.romPath,
                                   md5: game.md5Hash)
    }

    /// Human-readable `"<filename> — <description>"` lines for an error alert.
    public static func describe(_ requirements: [PerGameBIOSRequirement]) -> [String] {
        requirements.map { "\($0.canonicalFilename) — \($0.biosDescription)" }
    }

    // MARK: - PVBIOS registration

    /// Create `PVBIOS` records for every BIOS file the manifest references, so
    /// the importer routes them into `<docs>/BIOS/<systemIdentifier>/` instead
    /// of mistaking them for ROMs, and the BIOS UI can list them.
    ///
    /// Rules:
    /// - Records are always `optional` — per-game files must not gate the whole
    ///   system. The per-launch check does the real enforcement.
    /// - Existing records (e.g. `naomi.zip` / `awbios.zip`, which already come
    ///   from `systems.plist`) are left completely untouched. `PVBIOS`'s primary
    ///   key is the filename and it holds a single `system` reference, so
    ///   re-seeding would silently reassign an existing record to another system.
    /// - Which system a file is filed under comes from the manifest's
    ///   `installSystem`, not from group ordering.
    /// - Only the canonical filename gets a record; alternate archive extensions
    ///   still satisfy the launch check, they just aren't advertised.
    public static func registerBIOSRecords(using database: RomDatabase = .sharedInstance) {
        let resolver = self.resolver
        guard !resolver.coveredSystemIdentifiers.isEmpty else { return }

        RomDatabase.refresh()
        var created = 0
        for systemID in resolver.coveredSystemIdentifiers {
            guard let system = database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: systemID),
                  !system.isInvalidated else {
                DLOG("PerGameBIOS: no PVSystem for \(systemID), skipping BIOS registration")
                continue
            }

            for file in resolver.biosFiles(forSystemIdentifier: systemID) {
                let filename = file.canonicalFilename
                /// Never touch a record that already exists — see the note above.
                if database.object(ofType: PVBIOS.self, wherePrimaryKeyEquals: filename) != nil { continue }

                let bios = PVBIOS(withSystem: system,
                                  descriptionText: file.description,
                                  optional: true,
                                  expectedMD5: file.md5 ?? "",
                                  expectedSize: file.size ?? 0,
                                  expectedFilename: filename)
                do {
                    try database.add(bios, update: true)
                    created += 1
                } catch {
                    ELOG("PerGameBIOS: failed to add BIOS \(filename): \(error)")
                }
            }
        }
        if created > 0 {
            ILOG("PerGameBIOS: registered \(created) per-game BIOS record(s)")
        }
    }
}
