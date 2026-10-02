//
//  RelativeMouseScalerTests.swift
//  PVLibRetroTests
//
//  Slow trackpad movement must add up to the same distance as fast movement:
//  sub-unit steps carry over instead of being truncated away.
//

import Testing
import PVSystems
@testable import PVCoreBridgeRetro

struct RelativeMouseScalerTests {

    @Test func wholeStepsPassThrough() {
        var scaler = RelativeMouseScaler()
        let units = scaler.units(dx: 0.5, dy: -0.25, scaleX: 320, scaleY: 200)
        #expect(units.x == 160)
        #expect(units.y == -50)
    }

    @Test func subUnitStepsAccumulate() {
        var scaler = RelativeMouseScaler()
        var totalX = 0
        var totalY = 0
        // 64 steps of a quarter unit each (binary-exact), 16 units in all.
        for _ in 0..<64 {
            let units = scaler.units(dx: 1.0 / 256, dy: -1.0 / 256, scaleX: 64, scaleY: 64)
            totalX += Int(units.x)
            totalY += Int(units.y)
        }
        #expect(totalX == 16)
        #expect(totalY == -16)
    }

    @Test func fullSweepCoversScale() {
        var scaler = RelativeMouseScaler()
        var total = 0
        for _ in 0..<1000 {
            total += Int(scaler.units(dx: 0.001, dy: 0, scaleX: 640, scaleY: 400).x)
        }
        // Floating-point steps may leave the last unit in the remainder.
        #expect((639...640).contains(total))
    }

    @Test func hugeDeltasClamp() {
        var scaler = RelativeMouseScaler()
        let units = scaler.units(dx: 1000, dy: -1000, scaleX: 1000, scaleY: 1000)
        #expect(units.x == Int16.max)
        #expect(units.y == Int16.min)
    }
}

struct RelativeMouseScaleTests {

    @Test func atariSTUsesFrameSize() {
        let scale = PVThinLibretroCore.relativeMouseScale(system: .AtariST, coreIdentifier: nil, frameWidth: 640, frameHeight: 400)
        #expect(scale.x == 640)
        #expect(scale.y == 400)
    }

    @Test func atariSTWithoutGeometryFallsBack() {
        let scale = PVThinLibretroCore.relativeMouseScale(system: .AtariST, coreIdentifier: nil, frameWidth: 0, frameHeight: 0)
        #expect(scale.x == PVThinLibretroCore.mouseScale)
        #expect(scale.y == PVThinLibretroCore.mouseScale)
    }

    @Test func dosLowResCoversVirtualScreen() {
        let scale = PVThinLibretroCore.relativeMouseScale(system: .DOS, coreIdentifier: nil, frameWidth: 320, frameHeight: 200)
        #expect(scale.x == PVThinLibretroCore.dosMinSweep.x)
        #expect(scale.y == PVThinLibretroCore.dosMinSweep.y)
    }

    @Test func dosTallModeScalesVertically() {
        let scale = PVThinLibretroCore.relativeMouseScale(system: .DOS, coreIdentifier: nil, frameWidth: 640, frameHeight: 480)
        #expect(scale.x == 640)
        #expect(scale.y == 960)
    }

    @Test func otherSystemsKeepFixedScale() {
        let scale = PVThinLibretroCore.relativeMouseScale(system: .DOOM, coreIdentifier: nil, frameWidth: 320, frameHeight: 200)
        #expect(scale.x == PVThinLibretroCore.mouseScale)
        #expect(scale.y == PVThinLibretroCore.mouseScale)
    }

    @Test func amigaCoreUsesFrameSize() {
        let scale = PVThinLibretroCore.relativeMouseScale(
            system: .RetroArch, coreIdentifier: "puae.libretro.framework", frameWidth: 720, frameHeight: 568
        )
        #expect(scale.x == 720)
        #expect(scale.y == 568)
    }

    @Test func msxUsesScreenSize() {
        for system in [SystemIdentifier.MSX, .MSX2] {
            let scale = PVThinLibretroCore.relativeMouseScale(system: system, coreIdentifier: nil, frameWidth: 272, frameHeight: 240)
            #expect(scale.x == PVThinLibretroCore.msxSweep.x)
            #expect(scale.y == PVThinLibretroCore.msxSweep.y)
        }
    }
}
