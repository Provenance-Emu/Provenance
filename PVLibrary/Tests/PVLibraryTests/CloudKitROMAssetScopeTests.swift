import XCTest
import CloudKit
@testable import PVLibrary

final class CloudKitROMAssetScopeTests: XCTestCase {
    func testArtworkProjectionNeverRequestsROMPayloads() {
        let keys = CloudKitRomsSyncer.recordFetchKeys(includeAssets: false, includeArtwork: true)
        XCTAssertTrue(keys.contains(CloudKitSchema.ROMFields.customArtworkAsset))
        XCTAssertTrue(keys.contains(CloudKitSchema.ROMFields.customArtworkURL))
        XCTAssertFalse(keys.contains(CloudKitSchema.ROMFields.fileData))
    }

    func testMetadataAndFullAssetRequestsKeepTheirExistingScope() {
        let metadata = CloudKitRomsSyncer.recordFetchKeys(includeAssets: false, includeArtwork: false)
        XCTAssertFalse(metadata.contains(CloudKitSchema.ROMFields.fileData))
        XCTAssertFalse(metadata.contains(CloudKitSchema.ROMFields.customArtworkAsset))
        let full = CloudKitRomsSyncer.recordFetchKeys(includeAssets: true, includeArtwork: false)
        XCTAssertTrue(full.contains(CloudKitSchema.ROMFields.fileData))
        XCTAssertTrue(full.contains(CloudKitSchema.ROMFields.customArtworkAsset))
    }
}
