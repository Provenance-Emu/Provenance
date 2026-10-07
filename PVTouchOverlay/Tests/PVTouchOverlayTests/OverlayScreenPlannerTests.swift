import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("OverlayScreenPlanner")
struct OverlayScreenPlannerTests {
    let portrait = OverlayLayoutEngineTests.phonePortrait
    let landscape = OverlayLayoutEngineTests.phoneLandscape

    func group(_ id: String, _ frame: CGRect,
               anchor: OverlayPlacement.Anchor = .bottomLeading) -> ResolvedGroup {
        let grp = OverlayGroup(id: id, controls: [], placement: OverlayPlacement(anchor: anchor))
        return ResolvedGroup(group: grp, frame: frame, controls: [], scale: CGSize(width: 1, height: 1), opacity: 1)
    }

    @Test("topBand fits the picture above the highest control, aspect-fit, centred")
    func topBand() {
        let groups = [group("dpad", CGRect(x: 0, y: 600, width: 150, height: 150))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .topBand, canvas: portrait,
                                                       groups: groups, gameAspect: 4.0 / 3.0)
        let frame = frames[0]
        #expect(frames.count == 1)
        #expect(frame.minY >= 59)
        #expect(frame.maxY <= 600 - OverlayScreenPlanner.gap)
        #expect(abs(frame.width / frame.height - 4.0 / 3.0) < 0.001)
        #expect(abs(frame.midX - 195) < 0.5)
    }

    @Test("centerColumn fits between the left and right clusters")
    func centerColumn() {
        let groups = [group("dpad", CGRect(x: 59, y: 100, width: 160, height: 160)),
                      group("face", CGRect(x: 844 - 59 - 160, y: 100, width: 160, height: 160))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .centerColumn, canvas: landscape,
                                                       groups: groups, gameAspect: 4.0 / 3.0)
        let frame = frames[0]
        #expect(frame.minX >= 59 + 160 + OverlayScreenPlanner.gap)
        #expect(frame.maxX <= 844 - 59 - 160 - OverlayScreenPlanner.gap)
        #expect(frame.maxY <= 390 - 21)
    }

    @Test("dualStacked yields two 4:3 screens, top first, inside the top band")
    func dualStacked() {
        let groups = [group("face", CGRect(x: 0, y: 650, width: 150, height: 150))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .dualStacked, canvas: portrait, groups: groups,
                                                       gameAspect: OverlayScreenPlanner.dsAspect)
        #expect(frames.count == 2)
        #expect(frames[0].maxY <= frames[1].minY)
        #expect(frames[1].maxY <= 650 - OverlayScreenPlanner.gap)
        #expect(abs(frames[0].width / frames[0].height - 4.0 / 3.0) < 0.001)
        #expect(frames[0].size == frames[1].size)
    }

    @Test("fill uses the whole safe rect")
    func fill() {
        let frames = OverlayScreenPlanner.screenFrames(policy: .fill, canvas: landscape,
                                                       groups: [], gameAspect: 16.0 / 9.0)
        #expect(frames == [landscape.safeRect])
    }

    func touchGroup(_ frame: CGRect) -> ResolvedGroup {
        let surface = OverlayControl(id: "ts", kind: .touchSurface(.trackpad),
                                     frame: CGRect(x: 0, y: 0, width: 10, height: 10),
                                     shape: .surface, paletteSlot: .utility)
        let grp = OverlayGroup(id: "ts", controls: [surface], placement: OverlayPlacement(anchor: .center))
        return ResolvedGroup(group: grp, frame: frame, controls: [], scale: CGSize(width: 1, height: 1), opacity: 1)
    }

    @Test("dualStacked centres the pair in a tall narrow band")
    func dualStackedCentred() {
        let groups = [group("face", CGRect(x: 0, y: 800, width: 150, height: 40))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .dualStacked, canvas: portrait, groups: groups,
                                                       gameAspect: OverlayScreenPlanner.dsAspect)
        let bandTop: CGFloat = 59
        let bandBottom: CGFloat = 800 - OverlayScreenPlanner.gap
        #expect(frames.count == 2)
        #expect(frames[0].minY >= bandTop)
        #expect(frames[1].maxY <= bandBottom)
        #expect(abs((frames[0].minY - bandTop) - (bandBottom - frames[1].maxY)) < 0.001)
        #expect(frames[0].minX >= 0 && frames[0].maxX <= 390)
    }

    @Test("topBand ignores top-anchored groups")
    func topBandIgnoresUpperGroups() {
        let groups = [group("float", CGRect(x: 0, y: 70, width: 100, height: 100), anchor: .topLeading)]
        let frames = OverlayScreenPlanner.screenFrames(policy: .topBand, canvas: portrait,
                                                       groups: groups, gameAspect: 1)
        #expect(frames[0].size.width == 390)
        #expect(frames[0].height == 390)
    }

    @Test("topBand reserves space for a bottom-anchored group even high on the canvas")
    func topBandReservesLiftedBottomGroup() {
        let groups = [group("shoulder", CGRect(x: 0, y: 300, width: 90, height: 40))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .topBand, canvas: portrait,
                                                       groups: groups, gameAspect: 1)
        #expect(frames[0].maxY <= 300 - OverlayScreenPlanner.gap)
    }

    @Test("topBand ignores touch-surface groups")
    func topBandIgnoresTouchSurface() {
        let groups = [touchGroup(CGRect(x: 0, y: 500, width: 390, height: 300))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .topBand, canvas: portrait,
                                                       groups: groups, gameAspect: 1)
        #expect(frames[0].width == 390)
    }

    @Test("centerColumn: a bottom-centre row lowers the bottom, not the width")
    func centerColumnCentredRow() {
        let groups = [group("dpad", CGRect(x: 59, y: 100, width: 160, height: 160)),
                      group("face", CGRect(x: 844 - 59 - 160, y: 100, width: 160, height: 160)),
                      group("pills", CGRect(x: 322, y: 300, width: 200, height: 40))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .centerColumn, canvas: landscape,
                                                       groups: groups, gameAspect: 4.0 / 3.0)
        #expect(frames[0].maxY <= 300 - OverlayScreenPlanner.gap)
        let column = OverlayScreenPlanner.centerColumn(safe: landscape.safeRect, groups: groups)
        #expect(column.minX == 59 + 160 + OverlayScreenPlanner.gap)
        #expect(column.maxX == 844 - 59 - 160 - OverlayScreenPlanner.gap)
        #expect(column.maxY == 300 - OverlayScreenPlanner.gap)
    }

    @Test("centerColumn ignores touch-surface groups")
    func centerColumnIgnoresTouchSurface() {
        let groups = [touchGroup(CGRect(x: 59, y: 0, width: 300, height: 300))]
        let column = OverlayScreenPlanner.centerColumn(safe: landscape.safeRect, groups: groups)
        #expect(column == landscape.safeRect)
    }
}
