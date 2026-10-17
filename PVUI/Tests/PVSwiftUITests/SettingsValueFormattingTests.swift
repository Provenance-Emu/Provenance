import Testing
@testable import PVSwiftUI

@Suite("AutoSaveIntervalRules")
struct AutoSaveIntervalRulesTests {

    @Test("Whole minutes read as integers, with singular for one")
    func wholeMinutes() {
        #expect(AutoSaveIntervalRules.durationLabel(60) == "1 minute")
        #expect(AutoSaveIntervalRules.durationLabel(600) == "10 minutes")
        #expect(AutoSaveIntervalRules.durationLabel(1800) == "30 minutes")
    }

    @Test("Fractional minutes keep one decimal")
    func fractionalMinutes() {
        #expect(AutoSaveIntervalRules.durationLabel(150) == "2.5 minutes")
    }

    @Test("Caption names the interval")
    func caption() {
        #expect(AutoSaveIntervalRules.caption(300) == "A save state is made every 5 minutes while you play.")
    }

    @Test("Presets sit inside the slider range, in ascending order")
    func presetsInRange() {
        let presets = AutoSaveIntervalRules.presets
        #expect(presets == presets.sorted())
        #expect(presets.allSatisfy { (AutoSaveIntervalRules.minimum...AutoSaveIntervalRules.maximum).contains($0) })
        // The stored default (10 minutes) is one of them.
        #expect(presets.contains(600))
    }

    @Test("A stored value that is not a preset is still offered, in order")
    func choicesIncludeCurrent() {
        #expect(AutoSaveIntervalRules.choices(including: 600) == AutoSaveIntervalRules.presets)
        let choices = AutoSaveIntervalRules.choices(including: 180)
        #expect(choices.contains(180))
        #expect(choices == choices.sorted())
        #expect(choices.count == AutoSaveIntervalRules.presets.count + 1)
    }
}

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
