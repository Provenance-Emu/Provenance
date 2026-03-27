//
//  MediaIntentHandlerTests.swift
//  PVSwiftUITests
//
//  Tests for the INPlayMediaIntent in-app handler added in PVAppDelegate+MediaIntent.swift.
//  These tests exercise the error / guard paths that do not require a live Realm database,
//  verifying that the handler returns the correct SiriKit response codes when no game
//  can be resolved from the intent.
//
//  Platform: iOS-only (INPlayMediaIntent is unavailable on tvOS).
//

import Testing
@testable import PVSwiftUI

#if os(iOS)
import Intents

// MARK: - Helpers

@available(iOS 14.0, *)
private func makeIntent(items: [INMediaItem]?) -> INPlayMediaIntent {
    INPlayMediaIntent(mediaItems: items,
                     mediaContainer: nil,
                     playShuffled: nil,
                     playbackRepeatMode: .unknown,
                     resumePlayback: nil,
                     playbackQueueLocation: .unknown,
                     playbackSpeed: nil,
                     mediaSearch: nil)
}

// MARK: - Test suite

@Suite("SiriKit INPlayMediaIntent Handler")
@available(iOS 14.0, *)
struct MediaIntentHandlerTests {

    // MARK: handle(intent:completion:) — guard paths

    @Test("handle: nil mediaItems → .failure")
    func handleNilMediaItemsReturnsFailure() async {
        let delegate = PVAppDelegate()
        let intent = makeIntent(items: nil)

        let response: INPlayMediaIntentResponse = await withCheckedContinuation { cont in
            delegate.handle(intent: intent) { cont.resume(returning: $0) }
        }

        #expect(response.code == .failure)
    }

    @Test("handle: empty mediaItems → .failure")
    func handleEmptyMediaItemsReturnsFailure() async {
        let delegate = PVAppDelegate()
        let intent = makeIntent(items: [])

        let response: INPlayMediaIntentResponse = await withCheckedContinuation { cont in
            delegate.handle(intent: intent) { cont.resume(returning: $0) }
        }

        #expect(response.code == .failure)
    }

    @Test("handle: mediaItem with nil identifier and nil title → .failure")
    func handleBlankMediaItemReturnsFailure() async {
        let delegate = PVAppDelegate()
        let blank = INMediaItem(identifier: nil, title: nil, type: .game, artwork: nil)
        let intent = makeIntent(items: [blank])

        let response: INPlayMediaIntentResponse = await withCheckedContinuation { cont in
            delegate.handle(intent: intent) { cont.resume(returning: $0) }
        }

        #expect(response.code == .failure)
    }

    @Test("handle: unknown MD5 identifier not in library → .failure")
    func handleUnknownMD5ReturnsFailure() async {
        let delegate = PVAppDelegate()
        let item = INMediaItem(identifier: "DEADBEEFDEADBEEFDEADBEEFDEADBEEF",
                              title: nil,
                              type: .game,
                              artwork: nil)
        let intent = makeIntent(items: [item])

        let response: INPlayMediaIntentResponse = await withCheckedContinuation { cont in
            delegate.handle(intent: intent) { cont.resume(returning: $0) }
        }

        // Realm lookup will find nothing → falls through to failure path
        #expect(response.code == .failure)
    }

    @Test("handle: title-only item with no matching game → .failure")
    func handleUnknownTitleReturnsFailure() async {
        let delegate = PVAppDelegate()
        let item = INMediaItem(identifier: nil,
                              title: "XYZZY_NONEXISTENT_GAME_12345",
                              type: .game,
                              artwork: nil)
        let intent = makeIntent(items: [item])

        let response: INPlayMediaIntentResponse = await withCheckedContinuation { cont in
            delegate.handle(intent: intent) { cont.resume(returning: $0) }
        }

        #expect(response.code == .failure)
    }

    // MARK: resolveMediaItems(for:with:) — guard paths

    @Test("resolveMediaItems: nil items → single needsValue result")
    func resolveNilMediaItemsReturnsNeedsValue() async {
        let delegate = PVAppDelegate()
        let intent = makeIntent(items: nil)

        let results: [INPlayMediaMediaItemResolutionResult] = await withCheckedContinuation { cont in
            delegate.resolveMediaItems(for: intent) { cont.resume(returning: $0) }
        }

        // Guard fires when mediaItems is nil → completion([.needsValue()])
        #expect(results.count == 1)
    }

    @Test("resolveMediaItems: unknown MD5 → unsupported result")
    func resolveUnknownMD5ReturnsUnsupported() async {
        let delegate = PVAppDelegate()
        let item = INMediaItem(identifier: "00000000000000000000000000000000",
                              title: nil,
                              type: .game,
                              artwork: nil)
        let intent = makeIntent(items: [item])

        let results: [INPlayMediaMediaItemResolutionResult] = await withCheckedContinuation { cont in
            delegate.resolveMediaItems(for: intent) { cont.resume(returning: $0) }
        }

        #expect(results.count == 1)
    }

    @Test("resolveMediaItems: item with no identifier and no title → needsValue result")
    func resolveBlankItemReturnsNeedsValue() async {
        let delegate = PVAppDelegate()
        let blank = INMediaItem(identifier: nil, title: nil, type: .game, artwork: nil)
        let intent = makeIntent(items: [blank])

        let results: [INPlayMediaMediaItemResolutionResult] = await withCheckedContinuation { cont in
            delegate.resolveMediaItems(for: intent) { cont.resume(returning: $0) }
        }

        #expect(results.count == 1)
    }
}
#endif
