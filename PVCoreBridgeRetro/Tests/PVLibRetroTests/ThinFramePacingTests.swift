//
//  ThinFramePacingTests.swift
//  PVLibRetroTests
//
//  The emulation loop ticks once per `emulationFrameDuration` and calls
//  retro_run once per tick, so one tick is one emulated frame. A core that
//  changes its frame rate after the loop started must re-pace the loop.
//  libretro MAME always does: it reports its default 60 fps at load (the
//  machine runs no frame inside retro_load_game) and the emulated screen's
//  refresh after the first frame, e.g. 57 Hz on Midway Seattle. At a stale
//  60 Hz tick the core emits audio for 1/57 s per tick, 5% more samples than
//  the device plays, so the audio ring fills and drops whole frames of sound
//  several times a second (issue #3761). Boards near 60 Hz drift too, just
//  rarely enough to go unnoticed.
//

import Foundation
import Testing
@testable import PVCoreBridgeRetro

@Suite(.serialized)
struct ThinFramePacingTests {

    private static let sampleRate = 48_000.0
    /// MAME's default `retro_fps`, reported at load before any frame has run.
    private static let loadFPS = 60.0
    /// Midway Seattle's refresh (`mame -listxml blitz`).
    private static let seattleFPS = 57.0

    private func reportAVInfo(_ frontend: PVThinLibretroFrontend, fps: Double) {
        var info = retro_system_av_info()
        info.geometry.base_width = 512
        info.geometry.base_height = 384
        info.geometry.max_width = 640
        info.geometry.max_height = 480
        info.geometry.aspect_ratio = 4.0 / 3.0
        info.timing.fps = fps
        info.timing.sample_rate = Self.sampleRate
        let handled = withUnsafeMutablePointer(to: &info) {
            frontend._testHandleEnvironmentCommand(UInt32(RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO), data: $0)
        }
        #expect(handled)
    }

    /// Starts the frontend the way `-[PVCoreObjCBridge startEmulation]` does:
    /// the load-time frame rate, then the game speed that fixes the loop's tick.
    private func startedFrontend(speed: GameSpeed = .normal) -> PVThinLibretroFrontend {
        let frontend = PVThinLibretroFrontend()
        reportAVInfo(frontend, fps: Self.loadFPS)
        frontend.gameSpeed = speed
        return frontend
    }

    @Test func loopTicksAtTheLoadTimeFrameRate() {
        let frontend = startedFrontend()
        #expect(abs(frontend.emulationFrameDuration - 1.0 / Self.loadFPS) < 1e-9)
    }

    @Test func loopRepacesWhenTheCoreReportsANewFrameRate() {
        let frontend = startedFrontend()

        reportAVInfo(frontend, fps: Self.seattleFPS)

        #expect(abs(frontend.emulationFrameDuration - 1.0 / Self.seattleFPS) < 1e-9)
    }

    /// The property the reporter hears: audio the core produces per second of
    /// wall-clock time must match what the device plays.
    @Test func audioProducedPerSecondMatchesTheSampleRateAfterAFrameRateChange() {
        let frontend = startedFrontend()

        reportAVInfo(frontend, fps: Self.seattleFPS)

        let samplesPerEmulatedFrame = Self.sampleRate / Self.seattleFPS
        let ticksPerSecond = 1.0 / frontend.emulationFrameDuration
        let producedPerSecond = samplesPerEmulatedFrame * ticksPerSecond
        let surplus = (producedPerSecond - Self.sampleRate) / Self.sampleRate
        // Before the fix: 60 ticks/s × 842 samples = +5.3%.
        #expect(abs(surplus) < 0.001, "audio surplus \(surplus * 100)% per second")
    }

    @Test func fastForwardSurvivesAFrameRateChange() {
        let frontend = startedFrontend(speed: .fast)

        reportAVInfo(frontend, fps: Self.seattleFPS)

        #expect(abs(frontend.emulationFrameDuration - 1.0 / (Self.seattleFPS * 2.0)) < 1e-9)
    }

    @Test func aFrameRateReportedBeforeStartIsPickedUpAtStart() {
        let frontend = PVThinLibretroFrontend()
        reportAVInfo(frontend, fps: Self.seattleFPS)
        #expect(frontend.emulationFrameDuration == 0)

        frontend.gameSpeed = .normal

        #expect(abs(frontend.emulationFrameDuration - 1.0 / Self.seattleFPS) < 1e-9)
    }
}
