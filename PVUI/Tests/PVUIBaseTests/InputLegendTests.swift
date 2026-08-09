//
//  InputLegendTests.swift
//  PVUIBaseTests
//
//  Tests for the in-game input legend's derivation rules. These exist because
//  the legend's whole value is that it doesn't lie: every case below is either
//  a real Systems.plist layout that must resolve to the system's own button
//  names, or a real layout that must REFUSE to resolve and fall back to
//  generic gamepad names.
//

#if !os(tvOS)
import Testing
import Foundation
import PVPlists
@testable import PVUIBase

struct InputLegendTests {

    // MARK: - Fixtures (verbatim from PVLibrary/Resources/Systems.plist)

    /// `ControlGroupButton`'s memberwise init is internal to PVPlists, so
    /// fixtures are decoded the same way the app decodes them.
    private static func buttons(_ json: String) -> [ControlGroupButton] {
        // swiftlint:disable:next force_try
        try! JSONDecoder().decode([ControlGroupButton].self, from: Data(json.utf8))
    }

    private static func layout(_ json: String) -> [ControlLayoutEntry] {
        // swiftlint:disable:next force_try
        try! JSONDecoder().decode([ControlLayoutEntry].self, from: Data(json.utf8))
    }

    private static let snesFaceButtons = buttons("""
    [{"PVControlType":"PVButton","PVControlTitle":"A","PVControlFrame":"{{110,60},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"B","PVControlFrame":"{{60,116},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"X","PVControlFrame":"{{60,4},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"Y","PVControlFrame":"{{4,60},{60,60}}"}]
    """)

    private static let psxFaceButtons = buttons("""
    [{"PVControlType":"PVButton","PVControlTitle":"○","PVControlFrame":"{{116,60},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"✕","PVControlFrame":"{{60,116},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"▵","PVControlFrame":"{{60,4},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"□","PVControlFrame":"{{4,60},{60,60}}"}]
    """)

    /// PC Engine: two buttons side by side. No bottom, no top — not a diamond.
    private static let pceFaceButtons = buttons("""
    [{"PVControlType":"PVButton","PVControlTitle":"Ⅱ","PVControlFrame":"{{20,70},{60,70}}"},
     {"PVControlType":"PVButton","PVControlTitle":"Ⅰ","PVControlFrame":"{{90,70},{60,70}}"}]
    """)

    /// Genesis: a stepped 3×2 block, six buttons.
    private static let genesisFaceButtons = buttons("""
    [{"PVControlType":"PVButton","PVControlTitle":"A","PVControlFrame":"{{8,92},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"B","PVControlFrame":"{{76,84},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"C","PVControlFrame":"{{144,76},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"X","PVControlFrame":"{{8,24},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"Y","PVControlFrame":"{{76,16},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"Z","PVControlFrame":"{{144,8},{60,60}}"}]
    """)

    /// MAME: the PlayStation-style diamond plus a "Coin" button in the corner.
    private static let mameFaceButtons = buttons("""
    [{"PVControlType":"PVButton","PVControlTitle":"○","PVControlFrame":"{{116,60},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"✕","PVControlFrame":"{{60,116},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"▵","PVControlFrame":"{{60,4},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"□","PVControlFrame":"{{4,60},{60,60}}"},
     {"PVControlType":"PVButton","PVControlTitle":"Coin","PVControlFrame":"{{4,4},{40,40}}"}]
    """)

    // MARK: - Face button geometry

    @Test("SNES diamond resolves positionally: MFi bottom is the console's B")
    func snesDiamondResolves() throws {
        let titles = try #require(FaceButtonGeometry.titles(for: Self.snesFaceButtons))
        // Verified against snes9x's own bridge, which reports
        // `PVSNESButtonB` for `gamepad.buttonA`.
        #expect(titles[.buttonA] == "B")
        #expect(titles[.buttonB] == "A")
        #expect(titles[.buttonX] == "Y")
        #expect(titles[.buttonY] == "X")
    }

    @Test("PlayStation diamond yields Cross/Circle/Square/Triangle")
    func psxDiamondResolves() throws {
        let titles = try #require(FaceButtonGeometry.titles(for: Self.psxFaceButtons))
        #expect(titles[.buttonA] == "✕")
        #expect(titles[.buttonB] == "○")
        #expect(titles[.buttonX] == "□")
        #expect(titles[.buttonY] == "▵")
    }

    @Test("Non-diamond layouts refuse to resolve rather than guessing")
    func nonDiamondLayoutsRefuse() {
        // Two side-by-side buttons: no bottom, no top.
        #expect(FaceButtonGeometry.titles(for: Self.pceFaceButtons) == nil, "PC Engine must not resolve")
        // Six buttons in a stepped block.
        #expect(FaceButtonGeometry.titles(for: Self.genesisFaceButtons) == nil, "Genesis must not resolve")
        // A diamond plus a corner "Coin" button — five, so not a diamond.
        #expect(FaceButtonGeometry.titles(for: Self.mameFaceButtons) == nil, "MAME must not resolve")
    }

    @Test("Frame strings parse to their centre point")
    func frameCentre() throws {
        let centre = try #require(FaceButtonGeometry.centre(ofFrameString: "{{60,116},{60,60}}"))
        #expect(centre.x == 90)
        #expect(centre.y == 146)
    }

    // MARK: - Non-face controls

    @Test("Shoulder titles pair by array order, not first-match-wins")
    func shouldersPairByOrder() {
        // PlayStation ships two PVLeftShoulderButton entries, L1 then L2.
        let layout = Self.layout("""
        [{"PVControlType":"PVLeftShoulderButton","PVControlSize":"{60,42}","PVControlTitle":"L1"},
         {"PVControlType":"PVLeftShoulderButton","PVControlSize":"{60,42}","PVControlTitle":"L2"},
         {"PVControlType":"PVRightShoulderButton","PVControlSize":"{60,42}","PVControlTitle":"R1"},
         {"PVControlType":"PVRightShoulderButton","PVControlSize":"{60,42}","PVControlTitle":"R2"}]
        """)
        let names = InputLegendBuilder.systemButtonNames(from: layout, faceNamesAreTrustworthy: false)
        #expect(names[.l1] == "L1")
        #expect(names[.l2] == "L2")
        #expect(names[.r1] == "R1")
        #expect(names[.r2] == "R2")
    }

    @Test("A single shoulder entry leaves the second trigger unnamed")
    func singleShoulderLeavesTriggerUnnamed() {
        // SNES ships one PVLeftShoulderButton titled "L".
        let layout = Self.layout("""
        [{"PVControlType":"PVLeftShoulderButton","PVControlSize":"{60,42}","PVControlTitle":"L"}]
        """)
        let names = InputLegendBuilder.systemButtonNames(from: layout, faceNamesAreTrustworthy: false)
        #expect(names[.l1] == "L")
        #expect(names[.l2] == nil)
    }

    @Test("Start and Select take the system's own words")
    func startSelectUseSystemVocabulary() {
        // PC Engine calls Start "Run"; Genesis calls Select "Mode".
        let layout = Self.layout("""
        [{"PVControlType":"PVStartButton","PVControlSize":"{60,42}","PVControlTitle":"Run"},
         {"PVControlType":"PVSelectButton","PVControlSize":"{120,42}","PVControlTitle":"Mode"}]
        """)
        let names = InputLegendBuilder.systemButtonNames(from: layout, faceNamesAreTrustworthy: false)
        #expect(names[.start] == "Run")
        #expect(names[.select] == "Mode")
    }

    @Test("Face names are withheld when the core's convention isn't vouched for")
    func faceNamesGatedOnCoreConvention() {
        let layout = Self.layout("""
        [{"PVControlType":"PVButtonGroup","PVControlSize":"{180,180}","PVGroupedButtons":
          [{"PVControlType":"PVButton","PVControlTitle":"A","PVControlFrame":"{{110,60},{60,60}}"},
           {"PVControlType":"PVButton","PVControlTitle":"B","PVControlFrame":"{{60,116},{60,60}}"},
           {"PVControlType":"PVButton","PVControlTitle":"X","PVControlFrame":"{{60,4},{60,60}}"},
           {"PVControlType":"PVButton","PVControlTitle":"Y","PVControlFrame":"{{4,60},{60,60}}"}]}]
        """)
        #expect(InputLegendBuilder.systemButtonNames(from: layout, faceNamesAreTrustworthy: false)[.buttonA] == nil)
        #expect(InputLegendBuilder.systemButtonNames(from: layout, faceNamesAreTrustworthy: true)[.buttonA] == "B")
    }

    // MARK: - Row assembly

    @Test("Rows are dropped for controls the system doesn't have")
    func rowsDroppedForAbsentControls() {
        // A layout with only a d-pad and Start: no shoulders, no stick clicks.
        let layout = Self.layout("""
        [{"PVControlType":"PVDPad","PVControlSize":"{180,180}"},
         {"PVControlType":"PVStartButton","PVControlSize":"{60,42}","PVControlTitle":"Start"}]
        """)
        var labels: [KeyboardControllerAction: String] = [:]
        KeyboardControllerAction.allCases.forEach { labels[$0] = "key" }

        let legend = InputLegendBuilder.legend(layout: layout, faceNamesAreTrustworthy: false, inputLabels: labels)
        let controls = legend.rows.map(\.controlLabel)
        #expect(controls.contains("D-Pad"))
        #expect(controls.contains("Start"))
        #expect(!controls.contains("Left Stick"))   // no PVJoyPad in the layout
        #expect(!controls.contains("L1"))           // no shoulder entries
        #expect(!controls.contains("Select"))       // no PVSelectButton
        // No PVButtonGroup either, so there are no face buttons to name.
        // Apple II is the real system in this shape.
        #expect(!controls.contains("A"))
        #expect(!legend.hasGenericFaceNames)
    }

    @Test("Unbound actions produce no row")
    func unboundActionsProduceNoRow() {
        let layout = Self.layout("""
        [{"PVControlType":"PVDPad","PVControlSize":"{180,180}"},
         {"PVControlType":"PVStartButton","PVControlSize":"{60,42}","PVControlTitle":"Start"}]
        """)
        let legend = InputLegendBuilder.legend(layout: layout, faceNamesAreTrustworthy: false, inputLabels: [:])
        #expect(legend.rows.isEmpty)
    }

    @Test("Generic face names are flagged so the view can say so")
    func genericFaceNamesAreFlagged() {
        let layout = Self.layout("""
        [{"PVControlType":"PVButtonGroup","PVControlSize":"{180,180}","PVGroupedButtons":
          [{"PVControlType":"PVButton","PVControlTitle":"Ⅱ","PVControlFrame":"{{20,70},{60,70}}"},
           {"PVControlType":"PVButton","PVControlTitle":"Ⅰ","PVControlFrame":"{{90,70},{60,70}}"}]}]
        """)
        var labels: [KeyboardControllerAction: String] = [:]
        KeyboardControllerAction.allCases.forEach { labels[$0] = "key" }

        let legend = InputLegendBuilder.legend(layout: layout, faceNamesAreTrustworthy: true, inputLabels: labels)
        #expect(legend.hasGenericFaceNames)
        #expect(legend.rows.map(\.controlLabel).contains("A"))
    }
}
#endif // !os(tvOS)
