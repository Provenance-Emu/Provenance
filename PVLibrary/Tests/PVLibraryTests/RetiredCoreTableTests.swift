//
//  RetiredCoreTableTests.swift
//  PVLibraryTests
//
//  Every retired-core replacement must be a libretro core the app registers
//  (CoresRetro/RetroArch/Core.plist), or the retirement never activates.
//

import XCTest
import PVRealm
import PVSystems

final class RetiredCoreTableTests: XCTestCase {
    private func libretroIdentifiers() throws -> Set<String> {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: repo.appendingPathComponent("CoresRetro/RetroArch/Core.plist"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let cores = try XCTUnwrap(plist["PVCores"] as? [[String: Any]])
        return Set(cores.compactMap { $0["PVCoreIdentifier"] as? String })
    }

    func testEveryReplacementIsARegisteredLibretroCore() throws {
        let known = try libretroIdentifiers()
        for (retiredID, retired) in PVCore.retiredCores {
            for replacement in retired.allReplacements {
                XCTAssertTrue(known.contains(replacement), "\(retiredID) → \(replacement) is not in Core.plist")
            }
        }
    }

    func testTableCoversThePrunedCores() {
        XCTAssertEqual(PVCore.retiredCores.count, 22)
        XCTAssertEqual(PVCore.retiredCores[RetiredCoreID.crabEMU]?.replacement(forSystem: SystemIdentifier.ColecoVision.rawValue),
                       LibretroCoreID.gearcoleco)
        XCTAssertEqual(PVCore.retiredCores[RetiredCoreID.atari800]?.replacement(forSystem: SystemIdentifier.Atari5200.rawValue),
                       LibretroCoreID.a5200)
        XCTAssertEqual(PVCore.retiredCores[RetiredCoreID.melonDS]?.batterySaves,
                       [.movedFromSaveStates("sav", copyToSRM: true)])
        XCTAssertTrue(PVCore.retiredCores.filter { $0.key != RetiredCoreID.jaguar }.values.allSatisfy { !$0.migratesSaveStates })
    }
}
