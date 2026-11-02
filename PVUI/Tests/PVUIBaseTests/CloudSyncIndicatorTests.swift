import Testing
@testable import PVUIBase

@Suite("Library cloud badges")
struct CloudSyncIndicatorTests {
    @Test("No cloud record never displays a badge", arguments: [true, false], [true, false])
    func noAssets(downloaded: Bool, syncEnabled: Bool) {
        #expect(CloudSyncIndicatorView.resolveStatus(isDownloaded: downloaded, hasCloudAssets: false,
                                                   isDownloading: true, syncEnabled: syncEnabled) == .none)
    }

    @Test("Turning off sync does not relabel an available local file")
    func localFileWithSyncOff() {
        #expect(CloudSyncIndicatorView.resolveStatus(isDownloaded: true, hasCloudAssets: true,
                                                   isDownloading: false, syncEnabled: false) == .downloaded)
        #expect(CloudSyncIndicatorView.resolveStatus(isDownloaded: false, hasCloudAssets: true,
                                                   isDownloading: false, syncEnabled: false) == .syncDisabled)
    }

    @Test("Transfer state takes precedence over the completed flag")
    func transfer() {
        #expect(CloudSyncIndicatorView.resolveStatus(isDownloaded: true, hasCloudAssets: true,
                                                   isDownloading: true, syncEnabled: true) == .downloading)
        #expect(CloudSyncIndicatorView.resolveStatus(isDownloaded: false, hasCloudAssets: true,
                                                   isDownloading: false, syncEnabled: true) == .available)
    }
}
