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
    @objc optional dynamic var shouldStop: Bool { get }
    @objc optional dynamic var isRunning: Bool { get }
    @objc optional dynamic var shouldResyncTime: Bool { get }
    @objc optional dynamic var skipEmulationLoop: Bool { get }
    @objc optional dynamic var skipLayout: Bool { get }

    @objc optional dynamic var gameSpeed: GameSpeed { get set }
    @objc optional dynamic var emulationLoopThreadLock: NSLock { get }
    @objc optional dynamic var frontBufferCondition: NSCondition { get }
    @objc optional dynamic var frontBufferLock: NSLock { get }
    @objc optional dynamic var isFrontBufferReady: Bool { get }
}

//public extension EmulatorCoreRunLoop {
//    dynamic var shouldStop: Bool { false }
//    dynamic var isRunning: Bool { false }
//    dynamic var shouldResyncTime: Bool { true }
//    dynamic var skipEmulationLoop: Bool { true }
//    dynamic var skipLayout: Bool { false }
//
//    dynamic var gameSpeed: GameSpeed { .normal }
//    dynamic var isFrontBufferReady: Bool { false }
//}
