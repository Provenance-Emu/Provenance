//
//  PVGPUViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/27/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import os
import Defaults
import PVSettings
#if canImport(UIKit)
import UIKit
#endif
#if canImport(QuartzCore)
import QuartzCore
#endif
import Metal
import CoreGraphics
#if canImport(OpenGL)
import OpenGL
#endif
#if canImport(OpenGLES)
import OpenGLES.ES3
#endif

#if os(macOS)
public typealias BaseViewController = NSViewController
#elseif targetEnvironment(macCatalyst)
public typealias BaseViewController = UIViewController
#else
import GLKit
#if USE_METAL
public typealias BaseViewController = UIViewController  /// Use UIViewController for Metal
#else
public typealias BaseViewController = GLKViewController /// Use GLKViewController for OpenGL
#endif
#endif


@objc
@objcMembers
public class PVGPUViewController: BaseViewController {
    var screenType: String = "crt"

    /// Flag to indicate that custom positioning is being used
    public var useCustomPositioning: Bool = false

    /// Custom frame to use when useCustomPositioning is true
    public var customFrame: CGRect = .zero

    #if os(macOS) || targetEnvironment(macCatalyst)
    public var isPaused: Bool = false
    public var framesPerSecond: Double = 0
    public var timeSinceLastDraw: TimeInterval = 0
    #else
    /// Frame timing for iOS - tracks last frame timestamp for FPS calculation
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var frameTimestamps: [CFTimeInterval] = []
    private let maxFrameTimestamps = 60
    /// Thread-safe access to frame timestamps
    private let frameTimestampsLock = OSAllocatedUnfairLock<Void>(initialState: ())
    private var didPostFirstFrameNotification: Bool = false
    private let firstFrameLock = OSAllocatedUnfairLock<Void>(initialState: ())
    #endif

    #if os(iOS)
    public override var prefersHomeIndicatorAutoHidden: Bool {
//        let shouldHideHomeIndicator: Bool = PVControllerManager.shared.hasControllers
//        return shouldHideHomeIndicator
        return true
    }

    public override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.left, .right, .bottom]
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }

    /// Track frame presentation for FPS calculation on iOS
    #endif

    /// Track frame presentation for FPS calculation and first-frame notification.
    /// Call this from GL/Metal draw paths after a frame is actually scheduled for presentation.
    @objc public func markFramePresented() {
        trackFramePresentation()

        let shouldPost = firstFrameLock.withLock { () -> Bool in
            let shouldPost = !didPostFirstFrameNotification
            if shouldPost {
                didPostFirstFrameNotification = true
            }
            return shouldPost
        }

        guard shouldPost else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .pvFirstFramePresented, object: self)
        }
    }

    /// Reset first-frame tracking when starting a new emulation session.
    @objc public func resetFirstFrameTracking() {
        frameTimestampsLock.withLock {
            frameTimestamps.removeAll()
            lastFrameTimestamp = 0
        }

        firstFrameLock.withLock {
            didPostFirstFrameNotification = false
        }
    }

    #if os(iOS) || os(tvOS)
    /// Track frame presentation for FPS calculation on iOS/tvOS
    @objc func trackFramePresentation() {
        let currentTime = CACurrentMediaTime()
        frameTimestampsLock.withLock {
            if lastFrameTimestamp > 0 {
                let frameTime = currentTime - lastFrameTimestamp
                frameTimestamps.append(frameTime)
                /// Use efficient removal - only resize when necessary
                if frameTimestamps.count > maxFrameTimestamps {
                    frameTimestamps.removeFirst()
                }
            }
            lastFrameTimestamp = currentTime
        }
    }
    #endif

    /// Calculate rendering FPS from tracked frame timestamps
    /// Note: For GLKViewController, this extends the base property
    #if os(iOS) || os(tvOS)
    #if !USE_METAL
    /// Override GLKViewController's timeSinceLastDraw property
    public override var timeSinceLastDraw: TimeInterval {
        get {
            frameTimestampsLock.withLock {
                guard !frameTimestamps.isEmpty else { return super.timeSinceLastDraw }
                /// Use efficient sum calculation
                let sum = frameTimestamps.reduce(0, +)
                return sum / Double(frameTimestamps.count)
            }
        }
    }
    #else
    /// Provide timeSinceLastDraw for Metal view controllers
    @objc public var timeSinceLastDraw: TimeInterval {
        get {
            frameTimestampsLock.withLock {
                guard !frameTimestamps.isEmpty else { return 0 }
                /// Use efficient sum calculation
                let sum = frameTimestamps.reduce(0, +)
                return sum / Double(frameTimestamps.count)
            }
        }
    }
    #endif
    #endif

    /// Calculate average FPS from tracked frame timestamps
    /// Note: For GLKViewController, framesPerSecond is Int, so we provide a Double version
    #if os(iOS) || os(tvOS)
    #if !USE_METAL
    /// GLKViewController has framesPerSecond as Int, so we can't override it
    /// Instead, provide a computed property that calculates from timestamps
    @objc public var calculatedFramesPerSecond: Double {
        get {
            frameTimestampsLock.withLock {
                guard !frameTimestamps.isEmpty else { return Double(super.framesPerSecond) }
                let sum = frameTimestamps.reduce(0, +)
                let avgFrameTime = sum / Double(frameTimestamps.count)
                return avgFrameTime > 0 ? 1.0 / avgFrameTime : Double(super.framesPerSecond)
            }
        }
    }
    #else
    /// Provide framesPerSecond for Metal view controllers
    @objc public var framesPerSecond: Double {
        get {
            frameTimestampsLock.withLock {
                guard !frameTimestamps.isEmpty else { return 0 }
                let sum = frameTimestamps.reduce(0, +)
                let avgFrameTime = sum / Double(frameTimestamps.count)
                return avgFrameTime > 0 ? 1.0 / avgFrameTime : 0
            }
        }
    }
    #endif
    #endif
}

public extension Notification.Name {
    /// Posted once per emulation session when the GPU view schedules its first presented frame.
    static let pvFirstFramePresented = Notification.Name("pvFirstFramePresented")
}
