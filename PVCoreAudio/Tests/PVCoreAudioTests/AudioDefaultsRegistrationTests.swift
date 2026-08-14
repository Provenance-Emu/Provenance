//
//  AudioDefaultsRegistrationTests.swift
//  PVCoreAudioTests
//
//  Regression guard for 05d333005b
//  "fix(audio): break swift_once deadlock wedging launch (0x8BADF00D)".
//

@testable import PVCoreAudio
import Defaults
import Foundation
import PVAudio
import XCTest

/// # What is being protected here
///
/// Every `Defaults.Key` declared in PVCoreAudio uses the **closure** `default:` overload
/// (`Key("name") { value }`) instead of the value overload (`Key("name", default: value)`).
/// That is not a style choice. The value overload ends its initializer in
/// `UserDefaults.register(defaults:)`, which posts `UserDefaults.didChangeNotification`;
/// block-based observers registered with `queue: .main` are delivered by wrapping the block
/// in an `NSOperation` and **blocking the posting thread** until it finishes. Because a Swift
/// `static let` initializer runs under `swift_once`, the first touch of such a key from a
/// background thread parks that thread on the main queue *while it owns the once token* — and
/// the main thread then blocks forever in `_dispatch_once_wait` on the same token. That
/// shipped as an `0x8BADF00D` watchdog kill on game launch.
///
/// The risk this suite exists to catch is somebody "tidying" these keys back to the plain
/// value overload. See the long-form rationale on `Defaults.Keys.auEffectsChain` in
/// `Sources/PVCoreAudio/AUFilters/AUFilterSettings.swift`.
final class AudioDefaultsRegistrationTests: XCTestCase {

    /// The five audio keys, paired with the name each is stored under.
    /// Touching `Defaults[...]` here is what forces every key's `swift_once` block to run,
    /// which the registration-domain test below depends on.
    private static let keyNames = [
        Defaults.Keys.auFiltersEnabled.name,
        Defaults.Keys.auEffectsChain.name,
        Defaults.Keys.audioRingBufferType.name,
        Defaults.Keys.audioEngine.name,
        Defaults.Keys.audioEngineDSPAlgorithm.name
    ]

    // MARK: - Documented defaults

    /// Each key must resolve to its documented default with nothing stored anywhere.
    ///
    /// With the closure overload the value comes from the key's `defaultValue` fallback
    /// (`Defaults[key]` is `suite._get(name) ?? key.defaultValue`) rather than from a
    /// registered default — which is exactly the property under test.
    func testAudioKeysResolveToDocumentedDefaultsOnACleanSuite() {
        assertNothingStored(for: Defaults.Keys.auFiltersEnabled)
        assertNothingStored(for: Defaults.Keys.auEffectsChain)
        assertNothingStored(for: Defaults.Keys.audioRingBufferType)
        assertNothingStored(for: Defaults.Keys.audioEngine)
        assertNothingStored(for: Defaults.Keys.audioEngineDSPAlgorithm)

        XCTAssertFalse(Defaults[.auFiltersEnabled])
        XCTAssertEqual(Defaults[.auEffectsChain], .empty)
        XCTAssertEqual(Defaults[.audioRingBufferType], .provenance)
        XCTAssertEqual(Defaults[.audioEngine], .avAudioEngineGameAudioEngine)
        XCTAssertEqual(Defaults[.audioEngineDSPAlgorithm], .SIMD_LinearInterpolation)

        // Same expectations stated against the fallback itself, so these stay meaningful even
        // if the process running the suite ever does acquire a stored value for one of them.
        XCTAssertFalse(Defaults.Keys.auFiltersEnabled.defaultValue)
        XCTAssertEqual(Defaults.Keys.auEffectsChain.defaultValue, .empty)
        XCTAssertEqual(Defaults.Keys.audioRingBufferType.defaultValue, .provenance)
        XCTAssertEqual(Defaults.Keys.audioEngine.defaultValue, .avAudioEngineGameAudioEngine)
        XCTAssertEqual(Defaults.Keys.audioEngineDSPAlgorithm.defaultValue, .SIMD_LinearInterpolation)
    }

    // MARK: - Absence of registration

    /// The sharp guard: after every key has been touched, none of their names may appear in
    /// `NSRegistrationDomain`. A key that is present there was written by
    /// `UserDefaults.register(defaults:)` — i.e. somebody switched it back to the value
    /// overload and re-armed the launch deadlock.
    ///
    /// The registration domain is process-global (registering through *any* `UserDefaults`
    /// instance shows up when read through another), and it is a *volatile* domain, so this
    /// assertion cannot be confused by a value the developer happens to have persisted.
    func testAudioKeysAreNeverWrittenIntoTheRegistrationDomain() {
        // Force each key's `static let` (and therefore its `swift_once` block) to run first —
        // otherwise the check below would pass trivially without proving anything.
        _ = Defaults[.auFiltersEnabled]
        _ = Defaults[.auEffectsChain]
        _ = Defaults[.audioRingBufferType]
        _ = Defaults[.audioEngine]
        _ = Defaults[.audioEngineDSPAlgorithm]

        let registered = UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)
        for name in Self.keyNames {
            XCTAssertNil(registered[name], """
                "\(name)" was registered via UserDefaults.register(defaults:). PVCoreAudio keys must \
                use the closure `default:` overload — see AUFilterSettings.swift and commit 05d333005b.
                """)
        }
    }

    /// Negative control for the test above: it proves the registration-domain check can
    /// actually observe a registration, so a passing guard means something.
    ///
    /// Runs against a throwaway `UserDefaults` suite so it neither reads nor writes the
    /// developer's real preferences.
    func testClosureOverloadDoesNotRegisterButValueOverloadDoes() throws {
        let suiteName = "com.provenance.PVCoreAudioTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { suite.removePersistentDomain(forName: suiteName) }

        let closureName = "closureOverloadProbe\(UInt32.random(in: .min ... .max))"
        let valueName = "valueOverloadProbe\(UInt32.random(in: .min ... .max))"

        let closureKey = Defaults.Key<Bool>(closureName, suite: suite, default: { true })
        XCTAssertTrue(Defaults[closureKey])
        XCTAssertNil(registrationDomainValue(for: closureName),
                     "The closure `default:` overload must not call UserDefaults.register(defaults:)")

        let valueKey = Defaults.Key<Bool>(valueName, default: true, suite: suite)
        XCTAssertTrue(Defaults[valueKey])
        XCTAssertNotNil(registrationDomainValue(for: valueName), """
            The value `default:` overload no longer registers, so the guard in \
            testAudioKeysAreNeverWrittenIntoTheRegistrationDomain can no longer fail and needs \
            a new mechanism.
            """)
    }

    // MARK: - Helpers

    private func registrationDomainValue(for name: String) -> Any? {
        UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)[name]
    }

    /// Asserts the key has no value in any domain of its suite — neither persisted nor
    /// registered — so `Defaults[key]` can only be coming from `key.defaultValue`.
    private func assertNothingStored<Value>(for key: Defaults.Key<Value>,
                                            file: StaticString = #filePath,
                                            line: UInt = #line) {
        XCTAssertNil(key.suite.object(forKey: key.name),
                     "\(key.name) should have no stored or registered value in a clean suite",
                     file: file, line: line)
    }
}
