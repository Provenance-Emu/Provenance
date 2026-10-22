#!/usr/bin/env python3
"""Run the production manual-copy path with deterministic lifecycle barriers."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
model = (root / 'PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/NearbyLibrariesModel.swift').read_text()
copy = model[model.index('    func copy(_ item:'):model.index('    // MARK: - Art')]
view = (root / 'PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/NearbyLibrariesView.swift').read_text()
peer_view = view[view.index('struct NearbyPeerLibraryView:'):]
def callback_body(source, marker):
    start = source.index(marker) + len(marker)
    depth = 1
    for end in range(start, len(source)):
        if source[end] == '{':
            depth += 1
        elif source[end] == '}':
            depth -= 1
            if depth == 0:
                return source[start:end]
    raise ValueError(f"Unterminated callback: {marker}")

view_appearance = callback_body(peer_view, '.onAppear {')
view_disappearance = callback_body(peer_view, '.onDisappear {')
browse = model[model.index('    func load()'):model.index('    private func runLoad()')]
appearance_marker = '    func appear()'
appearance = model[model.index(appearance_marker):model.index('    func load()')] if appearance_marker in model else ''
owner_acquire = model[model.index('    func start()'):model.index('    private func startBrowsing()')]
owner_release = model[model.index('    func stop()'):model.index('    private func stopBrowsing()')]
appearance_view = '@MainActor struct PeerAppearanceHarness {\n    let model: ManualCopyHarness\n    func appear() {' + view_appearance + '\n    }\n    func disappear() {' + view_disappearance + '\n    }\n}\n'

automatic = (root / 'PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/NearbyLibraryAutomaticService.swift').read_text()
can_run = automatic[automatic.index('    private var canRun:'):automatic.index('\n', automatic.index('    private var canRun:'))]
manual_api = automatic[automatic.index('    func canReceiveManually'):automatic.index('    func setEnabled', automatic.index('    func canReceiveManually'))] if '    func canReceiveManually' in automatic else '''
    func canReceiveManually(from id: String) -> Bool { canRun && trustedIDs.contains(id) }
    func peerWasRevoked(_ id: String) { trustedIDs.remove(id); environmentChanged() }
    func sceneChanged(_ phase: ScenePhase) { active = phase == .active; environmentChanged() }
'''
subscription_start = model.find('        receiveEnvironmentObservation =')
subscription = model[subscription_start:model.index('\n    }\n\n    var title:', subscription_start)] if subscription_start >= 0 else ''
lifetime_start = model.find('struct NearbyDiscoveryLifetime')
lifetime = model[lifetime_start:model.index('/// Discovery plus', lifetime_start)] if lifetime_start >= 0 else ''
state = model[model.index('enum NearbyCopyState:'):model.index('/// Browsing one peer:')]
# The original model has no lifecycle hook. Keep that absence observable in the red run.
marker = '    func receiveEnvironmentChanged()'
hook = model[model.index(marker):model.index('    // MARK: - Browse', model.index(marker))] if marker in model else '    func receiveEnvironmentChanged() {}\n'
stubs = '''import Foundation
import Combine
func ILOG(_ s: String) {}
func WLOG(_ s: String) {}
enum LibraryBrowseProgress: Equatable { case connecting }
enum LibraryPullProgress { case preparing(LibraryBrowseProgress), downloading(Int, Int, Int, Int64, Int64), verifying }
struct RemoteLibraryItem { let id: String; var title = "Game"; var systemIdentifier: String? = "gc" }
enum ScenePhase { case active, inactive, background }
enum PeerApp { case iCube }
enum Flag { case nearbyLibraries }
final class PVFeatureFlags {
    static let shared = PVFeatureFlags()
    func isEnabled(_ flag: Flag) -> Bool { true }
}
struct Advertisement { var peerId: String? = "peer" }
struct Peer { var id = "icube:peer"; var serviceName = "Peer"; var app = PeerApp.iCube; var advertisement = Advertisement() }
protocol LibrarySource {}
struct ICubeContinuitySource: LibrarySource {}
struct Staging { func markHandedOff(_ url: URL) {} }
@MainActor final class Owner {
    var staging = Staging()
    var discovered = true
    var discoveryLifetime = NearbyDiscoveryLifetime()
    var browsing = true
    init(initiallyBrowsing: Bool = true) { browsing = initiallyBrowsing; discovered = initiallyBrowsing }
    func isDiscovered(_ peer: Peer) -> Bool { discovered && browsing }
    func startBrowsing() { browsing = true; discovered = true }
    func stopBrowsing() { browsing = false; discovered = false }
''' + owner_acquire + owner_release + '''}
struct Pulled { var skippedKinds: [String] = []; var gameFiles: [URL] = []; var folder = URL(fileURLWithPath: "/tmp") }
struct LibraryPuller {
    init(staging: Staging, peerKey: String) {}
    func pull(_ item: RemoteLibraryItem, from source: any LibrarySource, progress: @escaping @Sendable (LibraryPullProgress) -> Void) async throws -> Pulled { Pulled() }
}
@MainActor final class GameImporter {
    static let shared = GameImporter()
    var isPausedForEmulation = false
    func addImports(forPaths: [URL], targetSystem: String) async {}
    func startProcessing() {}
}
@MainActor final class NearbyLibraryAutomaticService {
    static let shared = NearbyLibraryAutomaticService()
    var active = true
    var trustedIDs: Set<String> = ["peer"]
    var trusted: Bool { get { trustedIDs.contains("peer") } set { trustedIDs = newValue ? ["peer"] : [] } }
    var emulating = false
    var booted = true
    let manualEnvironmentDidChange = PassthroughSubject<Void, Never>()
    func environmentChanged() { manualEnvironmentDidChange.send() }
    var allowsManualDiscovery: Bool { canRun }
''' + can_run + '\n' + manual_api + '''}

actor Barrier {
    var arrival: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    var arrived = false
    func suspend() async {
        await withCheckedContinuation { release = $0; arrived = true; arrival?.resume(); arrival = nil }
    }
    func wait() async { if !arrived { await withCheckedContinuation { arrival = $0 } } }
    func resume() { release?.resume(); release = nil }
}
@MainActor enum NearbyLibraryReceiveService {
    static var barrier = Barrier()
    static var eligibilityRejected = false
    static func receive(_ item: RemoteLibraryItem, source: ICubeContinuitySource, peerKey: String, staging: Staging,
                        checkEligibility: @escaping @MainActor () throws -> Void = {},
                        progress: @escaping @Sendable (LibraryPullProgress) -> Void) async throws -> Bool {
        await barrier.suspend()
        // Simulate a cancellation-insensitive transport completion and a delayed progress delivery.
        progress(.verifying)
        do { try checkEligibility() } catch { eligibilityRejected = true; throw error }
        return true
    }
}
@MainActor final class ManualCopyHarness {
    var peer = Peer()
    var owner: Owner?
    var source: any LibrarySource = ICubeContinuitySource()
    var copies: [String: NearbyCopyState] = [:]
    var copyTasks: [String: Task<Void, Never>] = [:]
    var copyGenerations: [String: UUID] = [:]
    var receiveEnvironmentObservation: AnyCancellable?
    enum Phase: Equatable { case idle, loading(LibraryBrowseProgress), loaded, confirmingCode, needsPairing }
    var phase = Phase.idle
    var loadTask: Task<Void, Never>?
    var catalogueLoads = 0
    func runLoad() async { catalogueLoads += 1; phase = .loaded }
    func finishLoading() async { await loadTask?.value }
    init(owner: Owner) {
        self.owner = owner
''' + subscription + '''
    }
    func finish(_ id: String) async { await copyTasks[id]?.value }
'''
tests = '''import XCTest
@testable import ManualHarness
final class ManualLifecycleTests: XCTestCase {
    @MainActor func runInvalidation(_ invalidate: (Owner, ManualCopyHarness) -> Void) async {
        let auto = NearbyLibraryAutomaticService.shared
        auto.active = true; auto.trusted = true; auto.emulating = false
        let barrier = Barrier()
        NearbyLibraryReceiveService.barrier = barrier
        NearbyLibraryReceiveService.eligibilityRejected = false
        let owner = Owner()
        let model = ManualCopyHarness(owner: owner)
        let item = RemoteLibraryItem(id: "game")
        model.copy(item)
        await barrier.wait()
        invalidate(owner, model)
        model.receiveEnvironmentChanged()
        await barrier.resume()
        await model.finish(item.id)
        await Task.yield()
        XCTAssertNil(model.copies[item.id], "invalidated manual receive published progress or completion")
        XCTAssertTrue(NearbyLibraryReceiveService.eligibilityRejected, "admission eligibility was not rechecked")
    }
    @MainActor func testReopeningCachedLoadedPeerReacquiresLeaseWithoutReloadingCatalogue() async {
        let auto = NearbyLibraryAutomaticService.shared
        auto.active = true; auto.trusted = true; auto.emulating = false
        let barrier = Barrier()
        NearbyLibraryReceiveService.barrier = barrier
        let owner = Owner(initiallyBrowsing: false)
        let model = ManualCopyHarness(owner: owner)
        let view = PeerAppearanceHarness(model: model)

        owner.start()
        view.appear()
        await model.finishLoading()
        XCTAssertEqual(model.phase, .loaded)
        XCTAssertEqual(model.catalogueLoads, 1)
        owner.stop() // Initial parent → child navigation.
        XCTAssertTrue(owner.browsing)

        owner.start() // Back to the parent.
        view.disappear()
        XCTAssertTrue(owner.discoveryLifetime.peerIDs.isEmpty)
        view.appear() // The same cached .loaded model appears again.
        view.appear() // Repeated appearances must remain idempotent.
        owner.stop() // Parent disappears while the cached child stays visible.
        XCTAssertTrue(owner.browsing, "cached peer appearance did not reacquire discovery")
        XCTAssertEqual(model.catalogueLoads, 1, "cached appearance must not reload the catalogue")

        let item = RemoteLibraryItem(id: "reopened-game")
        model.copy(item)
        if let task = model.copyTasks[item.id] {
            await barrier.wait()
            await barrier.resume()
            await task.value
            XCTAssertEqual(model.copies[item.id], .completed)
        } else {
            XCTFail("manual copy from the reopened cached peer is ineligible")
        }

        view.disappear() // True exit; the parent is already absent.
        XCTAssertTrue(owner.discoveryLifetime.peerIDs.isEmpty)
        XCTAssertFalse(owner.browsing, "true peer exit leaked discovery ownership")
    }
    @MainActor func testSceneNotificationInvalidatesSynchronouslyBeforeAdmissionResumes() async {
        let auto = NearbyLibraryAutomaticService.shared
        auto.active = true; auto.trusted = true; auto.emulating = false
        let barrier = Barrier()
        NearbyLibraryReceiveService.barrier = barrier
        let owner = Owner()
        let model = ManualCopyHarness(owner: owner)
        model.copy(RemoteLibraryItem(id: "game"))
        await barrier.wait()
        auto.sceneChanged(.inactive)
        XCTAssertNil(model.copyGenerations["game"], "scene invalidation must synchronously cancel the generation")
        await barrier.resume()
        await model.finish("game")
        XCTAssertNil(model.copies["game"])
    }
    @MainActor func testBackgroundInvalidatesManualGeneration() async {
        await runInvalidation { _, _ in NearbyLibraryAutomaticService.shared.sceneChanged(.background) }
    }
    @MainActor func testTrustRevocationInvalidatesManualGeneration() async {
        await runInvalidation { _, _ in NearbyLibraryAutomaticService.shared.peerWasRevoked("peer") }
    }
    @MainActor func testDiscoveryLossInvalidatesManualGeneration() async {
        await runInvalidation { owner, _ in owner.discovered = false }
    }
    @MainActor func testEmulationInvalidatesManualGeneration() async {
        await runInvalidation { _, _ in NearbyLibraryAutomaticService.shared.emulating = true }
    }
    @MainActor func testExplicitStopRejectsLateTransportAndProgress() async {
        await runInvalidation { _, model in model.cancelCopy(RemoteLibraryItem(id: "game")) }
    }
    @MainActor func testEligibilityRestorationDoesNotReviveOldGeneration() async {
        await runInvalidation { _, model in
            let auto = NearbyLibraryAutomaticService.shared
            auto.active = false
            model.receiveEnvironmentChanged()
            auto.active = true
        }
    }
}
'''
if lifetime:
    tests += """
final class DiscoveryLifetimeTests: XCTestCase {
    func testParentChildBackExitBalancesDiscoveryOwnership() {
        var lifetime = NearbyDiscoveryLifetime()
        XCTAssertFalse(lifetime.shouldBrowse(environmentEligible: true))
        lifetime.libraryVisible = true
        XCTAssertTrue(lifetime.shouldBrowse(environmentEligible: true))
        lifetime.peerIDs.insert("peer")
        lifetime.libraryVisible = false // Parent disappears because navigation pushed the peer.
        XCTAssertTrue(lifetime.shouldBrowse(environmentEligible: true))
        lifetime.libraryVisible = true // Back returns to the parent before peer disappear.
        lifetime.peerIDs.remove("peer")
        XCTAssertTrue(lifetime.shouldBrowse(environmentEligible: true))
        lifetime.libraryVisible = false // True settings exit.
        XCTAssertFalse(lifetime.shouldBrowse(environmentEligible: true))
    }
    func testBackgroundStopsDiscoveryWithVisiblePeerAndResumeRespectsOwnership() {
        var lifetime = NearbyDiscoveryLifetime()
        lifetime.peerIDs.insert("peer")
        XCTAssertTrue(lifetime.shouldBrowse(environmentEligible: true))
        XCTAssertFalse(lifetime.shouldBrowse(environmentEligible: false))
        XCTAssertTrue(lifetime.shouldBrowse(environmentEligible: true))
        lifetime.peerIDs.remove("peer")
        XCTAssertFalse(lifetime.shouldBrowse(environmentEligible: true))
    }
}
"""
with tempfile.TemporaryDirectory(prefix='provenance-nearby-manual-') as name:
    package = Path(name)
    (package/'Sources').mkdir(); (package/'Tests').mkdir()
    (package/'Sources/Manual.swift').write_text(stubs + hook + appearance + browse + copy + '}\n' + state + lifetime + appearance_view)
    (package/'Tests/ManualTests.swift').write_text(tests)
    (package/'Package.swift').write_text('''// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "ManualHarness", platforms: [.macOS(.v14)], targets: [
.target(name: "ManualHarness", path: "Sources"),
.testTarget(name: "ManualTests", dependencies: ["ManualHarness"], path: "Tests")])
''')
    raise SystemExit(subprocess.call(['swift', 'test', '--package-path', str(package), '--jobs', '4']))
