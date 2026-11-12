#if os(iOS) || os(tvOS)
import PVUIBase
import XCTest
@testable import PVSwiftUI

@MainActor
final class NearbyNavigationTests: XCTestCase {
    // MARK: Navigator

    func testBackPopsThenCloses() {
        var closed = 0
        let navigator = NearbyNavigator()
        navigator.onClose = { closed += 1 }
        navigator.push(.peer(id: "pvlibrary:abc"))
        navigator.push(.librarySharing)

        navigator.back()
        XCTAssertEqual(navigator.path, [.peer(id: "pvlibrary:abc")])
        navigator.back()
        XCTAssertEqual(navigator.path, [])
        XCTAssertEqual(closed, 0)
        navigator.back()
        XCTAssertEqual(closed, 1)
    }

    func testOnlyTheTopScreenIsActive() {
        let navigator = NearbyNavigator()
        XCTAssertTrue(navigator.isTopScreen(nil))

        navigator.push(.automaticCopies)
        XCTAssertFalse(navigator.isTopScreen(nil))
        XCTAssertTrue(navigator.isTopScreen(.automaticCopies))

        navigator.isSubsheetPresented = true
        XCTAssertFalse(navigator.isTopScreen(.automaticCopies), "Add Content Server owns the controller while it is up")
    }

    // MARK: Commands

    private let list = NearbyCursor.home(peerIDs: ["a", "b"], serverPeerIDs: [], showsContentServers: false, showsOpenSettings: false)

    func testFirstPressOnlyShowsTheCursor() {
        XCTAssertEqual(NearbyCursorCommand.resolve(.buttonPress(true), layout: list, cursor: nil), .move(NearbyCursor.librarySharing))
        XCTAssertEqual(
            NearbyCursorCommand.resolve(.verticalNavigation(-1, true), layout: list, cursor: nil),
            .move(NearbyCursor.librarySharing)
        )
    }

    func testCursorThatLeftTheScreenIsNotActivated() {
        XCTAssertEqual(
            NearbyCursorCommand.resolve(.buttonPress(true), layout: list, cursor: NearbyCursor.peer("gone")),
            .move(NearbyCursor.librarySharing)
        )
    }

    func testDpadMovesAndAActivates() {
        XCTAssertEqual(
            NearbyCursorCommand.resolve(.verticalNavigation(-1, true), layout: list, cursor: NearbyCursor.automaticCopies),
            .move(NearbyCursor.peer("a"))
        )
        XCTAssertEqual(
            NearbyCursorCommand.resolve(.verticalNavigation(1, true), layout: list, cursor: NearbyCursor.librarySharing),
            .none, "Up from the first row goes nowhere"
        )
        XCTAssertEqual(
            NearbyCursorCommand.resolve(.buttonPress(true), layout: list, cursor: NearbyCursor.peer("b")),
            .activate(NearbyCursor.peer("b"))
        )
    }

    func testReleasesAndOtherButtonsDoNothing() {
        XCTAssertEqual(NearbyCursorCommand.resolve(.buttonPress(false), layout: list, cursor: NearbyCursor.peer("a")), .none)
        XCTAssertEqual(NearbyCursorCommand.resolve(.verticalNavigation(-1, false), layout: list, cursor: nil), .none)
        XCTAssertEqual(NearbyCursorCommand.resolve(.start(true), layout: list, cursor: nil), .none)
        XCTAssertEqual(NearbyCursorCommand.resolve(.buttonB(true), layout: list, cursor: nil), .back)
    }

    func testTypingInAFieldOnlyLetsBLeaveIt() {
        let cursor = NearbyCursor.peer("a")
        XCTAssertEqual(
            NearbyCursorCommand.resolve(.buttonPress(true), layout: list, cursor: cursor, isEditingText: true), .none
        )
        XCTAssertEqual(
            NearbyCursorCommand.resolve(.verticalNavigation(-1, true), layout: list, cursor: cursor, isEditingText: true),
            .none
        )
        XCTAssertEqual(
            NearbyCursorCommand.resolve(.buttonB(true), layout: list, cursor: cursor, isEditingText: true), .back
        )
        XCTAssertEqual(
            NearbyCursorCommand.resolve(
                .buttonB(true), layout: list, cursor: cursor, isEditingText: true, isKeyboardAttached: true
            ),
            .none, "With a keyboard, F is B: typing an F must not leave the field"
        )
    }

    // MARK: Layouts

    func testHomeListsContentServersWithTheirRemoveButton() {
        let layout = NearbyCursor.home(peerIDs: ["a"], serverPeerIDs: ["s"], showsContentServers: true, showsOpenSettings: true)
        XCTAssertEqual(layout.rows.map(\.items), [
            [NearbyCursor.librarySharing],
            [NearbyCursor.automaticCopies],
            [NearbyCursor.peer("a")],
            [NearbyCursor.peer("s"), NearbyCursor.removeServer("s")],
            [NearbyCursor.addServer],
            [NearbyCursor.openSettings]
        ])
        XCTAssertEqual(layout.move(from: NearbyCursor.peer("s"), .right), .moved(item: NearbyCursor.removeServer("s"), row: NearbyCursor.peer("s")))
    }

    func testHomeHidesContentServersWhenTheFlagIsOff() {
        let layout = NearbyCursor.home(peerIDs: [], serverPeerIDs: ["s"], showsContentServers: false, showsOpenSettings: false)
        XCTAssertFalse(layout.contains(NearbyCursor.peer("s")))
        XCTAssertFalse(layout.contains(NearbyCursor.addServer))
    }

    func testLoadedLibraryStartsBelowSearch() {
        let layout = NearbyCursor.peerLibrary(.loaded(libraryIDs: ["", "lib1"], itemIDs: ["g1", "g2"]))
        XCTAssertEqual(layout.defaultItem, NearbyCursor.library(""))
        XCTAssertEqual(layout.rows.first?.items, [NearbyCursor.search])
        XCTAssertEqual(layout.move(from: NearbyCursor.library(""), .right), .moved(item: NearbyCursor.library("lib1"), row: "peer|libraries"))
        XCTAssertEqual(layout.move(from: NearbyCursor.library("lib1"), .down), .moved(item: NearbyCursor.item("g1"), row: NearbyCursor.item("g1")))

        let plain = NearbyCursor.peerLibrary(.loaded(libraryIDs: [], itemIDs: ["g1"]))
        XCTAssertEqual(plain.defaultItem, NearbyCursor.item("g1"))
    }

    func testPeerPhasesOfferTheirOneControl() {
        XCTAssertTrue(NearbyCursor.peerLibrary(.waiting).isEmpty)
        XCTAssertEqual(NearbyCursor.peerLibrary(.failed).defaultItem, NearbyCursor.tryAgain)
        XCTAssertEqual(NearbyCursor.peerLibrary(.needsPairing).defaultItem, NearbyCursor.pair)
        XCTAssertEqual(NearbyCursor.peerLibrary(.enteringCode).rows.map(\.items), [[NearbyCursor.code], [NearbyCursor.submitCode]])
    }

    func testTrustedDeviceRowHoldsItsChoicesAndRemove() {
        let layout = NearbyCursor.librarySharing(systems: ["sys"], trustedPeerIDs: ["p"], grants: ["everything", "askPerGame", "denied"])
        XCTAssertEqual(layout.rows.last?.items, [
            NearbyCursor.grant("everything", peer: "p"),
            NearbyCursor.grant("askPerGame", peer: "p"),
            NearbyCursor.grant("denied", peer: "p"),
            NearbyCursor.removePeer("p")
        ])
        XCTAssertEqual(layout.defaultItem, NearbyCursor.sharingSwitch)
    }

    func testAutomaticCopiesShowsActionsOnlyWithASource() {
        XCTAssertTrue(NearbyCursor.automaticCopies(peerIDs: [], hasEnabledSources: false).isEmpty)
        let layout = NearbyCursor.automaticCopies(peerIDs: ["p"], hasEnabledSources: true)
        XCTAssertEqual(layout.rows.map(\.items), [[NearbyCursor.source("p")], [NearbyCursor.checkAgain], [NearbyCursor.stopAll]])
    }

    func testAddServerFieldsFollowTheTokenSwitch() {
        XCTAssertEqual(NearbyCursor.addServer(usesToken: true).rows.flatMap(\.items), [
            NearbyCursor.address, NearbyCursor.useToken, NearbyCursor.token, NearbyCursor.cancel, NearbyCursor.add
        ])
        XCTAssertEqual(NearbyCursor.addServer(usesToken: false).rows.flatMap(\.items), [
            NearbyCursor.address, NearbyCursor.useToken, NearbyCursor.username, NearbyCursor.password,
            NearbyCursor.cancel, NearbyCursor.add
        ])
    }

    // MARK: Game rows

    func testItemActionFollowsTheCopy() {
        XCTAssertEqual(NearbyItemAction(copyState: nil, inLibrary: false, canPlay: false, isContentServer: false), .copy)
        XCTAssertEqual(NearbyItemAction(copyState: nil, inLibrary: false, canPlay: false, isContentServer: true), .downloadAndPlay)
        XCTAssertEqual(NearbyItemAction(copyState: .downloading(0.5), inLibrary: false, canPlay: false, isContentServer: false), .stop)
        XCTAssertEqual(NearbyItemAction(copyState: .importing, inLibrary: false, canPlay: false, isContentServer: false), .importing)
        XCTAssertEqual(NearbyItemAction(copyState: .failed("x"), inLibrary: false, canPlay: false, isContentServer: false), .retry)
        XCTAssertEqual(NearbyItemAction(copyState: .completed, inLibrary: false, canPlay: false, isContentServer: false), .inLibrary)
        XCTAssertEqual(NearbyItemAction(copyState: nil, inLibrary: true, canPlay: false, isContentServer: false), .inLibrary)
        XCTAssertEqual(NearbyItemAction(copyState: nil, inLibrary: true, canPlay: true, isContentServer: true), .play)
        XCTAssertFalse(NearbyItemAction.inLibrary.isActionable)
        XCTAssertTrue(NearbyItemAction.copy.isActionable)
    }
}
#endif
