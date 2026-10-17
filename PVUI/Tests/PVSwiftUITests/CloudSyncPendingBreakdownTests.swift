import Testing
@testable import PVSwiftUI

@Suite("CloudSyncPendingBreakdown")
struct CloudSyncPendingBreakdownTests {

    @Test("Folder names from both sync backends land on one content type")
    func foldersMergeIntoTypes() {
        let items = CloudSyncPendingBreakdown.items(from: [
            (directories: ["Saves"], pending: 2),          // CloudKit
            (directories: ["Save States"], pending: 3),    // iCloud Drive
            (directories: ["BIOS", "System"], pending: 1)
        ])
        #expect(items == [
            CloudSyncPendingItem(label: "Save States", count: 5),
            CloudSyncPendingItem(label: "BIOS", count: 1)
        ])
    }

    @Test("Types with nothing pending are left out, and order follows the known types")
    func orderAndEmpty() {
        let items = CloudSyncPendingBreakdown.items(from: [
            (directories: ["DeltaSkins"], pending: 4),
            (directories: ["ROMs"], pending: 0),
            (directories: ["ROMs"], pending: 7)
        ])
        #expect(items.map(\.label) == ["ROMs", "Skins"])
        #expect(items.first?.count == 7)
    }

    @Test("Unknown folders are listed by name after the known types")
    func unknownFolders() {
        let items = CloudSyncPendingBreakdown.items(from: [
            (directories: ["Cheats"], pending: 2),
            (directories: ["ROMs"], pending: 1)
        ])
        #expect(items.map(\.label) == ["ROMs", "Cheats"])
    }

    @Test("Nothing pending gives no items")
    func nothingPending() {
        #expect(CloudSyncPendingBreakdown.items(from: []).isEmpty)
    }
}
