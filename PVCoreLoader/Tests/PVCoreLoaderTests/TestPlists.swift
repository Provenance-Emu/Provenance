import XCTest
import PVCoreBridge
@testable import PVCoreLoader

#if canImport(PVAtari800)
@_exported import PVAtari800
#endif
#if canImport(PVPicoDrive)
@_exported import PVPicoDrive
#endif
#if canImport(PVPokeMini)
@_exported import PVPokeMini
#endif
#if canImport(PVStella)
@_exported import PVStella
#endif
#if canImport(PVTGBDUal)
@_exported import PVTGBDUal
#endif
#if canImport(PVVirtualJaguar)
@_exported import PVVirtualJaguar
@_exported import PVVirtualJaguarC
@_exported import PVVirtualJaguarSwift
#endif

final class PVCoreLoaderTests: XCTestCase {

    func testVirtualJaguar() throws {
        let jaguarPlist = PVVirtualJaguarSwift.PVJaguarGameCore.corePlist

        XCTAssertNotNil(jaguarPlist)
    }

    func testGetCorePlists() async {
        let corePlists: [EmulatorCoreInfoPlist] = CoreLoader.shared.getCorePlists()

        // Check that the returned array is not empty
        XCTAssertFalse(corePlists.isEmpty, "The corePlists array should not be empty")

        let debugInfo = corePlists.map {
            "\($0.identifier) impliments \($0.supportedSystems.joined(separator: ","))"
        }
        print(debugInfo)
    }
}
