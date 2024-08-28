//
//  EmulatorCoreRunLoop.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

@objc public enum GameSpeed: Int {
    case slow, normal, fast
}

@objc public protocol EmulatorCoreRunLoop {
    var shouldStop: Bool { get }
    var isRunning: Bool { get }
    var shouldResyncTime: Bool { get }
    var skipEmulationLoop: Bool { get }
    var skipLayout: Bool { get }

    var gameSpeed: GameSpeed { get set }
    var emulationLoopThreadLock: NSLock { get }
    var frontBufferCondition: NSCondition { get }
    var frontBufferLock: NSLock { get }
    var isFrontBufferReady: Bool { get }
}

public extension EmulatorCoreRunLoop {
    var shouldStop: Bool { false }
    var isRunning: Bool { false }
    var shouldResyncTime: Bool { true }
    var skipEmulationLoop: Bool { true }
    var skipLayout: Bool { false }

    var gameSpeed: GameSpeed { .normal }
    var isFrontBufferReady: Bool { false }
}
