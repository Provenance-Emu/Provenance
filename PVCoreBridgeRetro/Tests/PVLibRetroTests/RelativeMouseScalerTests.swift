//
//  RelativeMouseScalerTests.swift
//  PVLibRetroTests
//
//  Slow trackpad movement must add up to the same distance as fast movement:
//  sub-unit steps carry over instead of being truncated away.
//

import Testing
@testable import PVLibRetro

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
