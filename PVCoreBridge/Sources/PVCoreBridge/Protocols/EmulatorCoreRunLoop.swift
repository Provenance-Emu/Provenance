//
//  EmulatorCoreRunLoop.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation



@objc public protocol EmulatorCoreRunLoop {
    @objc dynamic var shouldStop: Bool { get set }
    @objc dynamic var isRunning: Bool { get set }
    @objc dynamic var shouldResyncTime: Bool { get set }
    @objc dynamic var skipEmulationLoop: Bool { get set }
    @objc dynamic var skipLayout: Bool { get set }

    @objc dynamic var gameSpeed: GameSpeed { get set }
    @objc dynamic var emulationLoopThreadLock: NSLock { get set }
    @objc dynamic var frontBufferCondition: NSCondition { get set }
    @objc dynamic var frontBufferLock: NSLock { get set }
    @objc dynamic var isFrontBufferReady: Bool { get set }
    
    @objc func stopEmulation()
    @objc func startEmulation()
    @objc optional func resetEmulation()
    @objc optional func emulationLoopThread()
}
