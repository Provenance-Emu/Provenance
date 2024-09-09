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

public extension EmulatorCoreRunLoop where Self: ObjCBridgedCore, Self.Core: EmulatorCoreRunLoop {
    dynamic var shouldStop: Bool { core.shouldStop ?? false }
    dynamic var isRunning: Bool { core.isRunning ?? false }
    dynamic var shouldResyncTime: Bool { core.shouldResyncTime ?? true }
    dynamic var skipEmulationLoop: Bool { core.skipEmulationLoop ?? true }
    dynamic var skipLayout: Bool { core.skipLayout ?? false }

    dynamic var gameSpeed: GameSpeed { core.gameSpeed ?? .normal }
    dynamic var isFrontBufferReady: Bool { core.isFrontBufferReady ?? false }
}
