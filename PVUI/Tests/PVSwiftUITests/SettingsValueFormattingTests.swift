import Testing
@testable import PVSwiftUI

@Suite("AppVersionLabel")
struct AppVersionLabelTests {

    @Test("Version and build number")
    func versionAndBuild() {
        #expect(AppVersionLabel.text(shortVersion: "3.4.0", build: "4521") == "3.4.0 (4521)")
    }

    @Test("Missing build number shows the version alone")
    func missingBuild() {
        #expect(AppVersionLabel.text(shortVersion: "3.4.0", build: nil) == "3.4.0")
        #expect(AppVersionLabel.text(shortVersion: "3.4.0", build: "") == "3.4.0")
    }

    @Test("Missing version reads Unknown")
    func missingVersion() {
        #expect(AppVersionLabel.text(shortVersion: nil, build: "4521") == "Unknown")
    }

    @Test("No channel wording such as Beta or AppStore")
    func noChannelWording() {
        let label = AppVersionLabel.text(shortVersion: "3.4.0", build: "4521").lowercased()
        #expect(!label.contains("beta"))
        #expect(!label.contains("appstore"))
    }
}
