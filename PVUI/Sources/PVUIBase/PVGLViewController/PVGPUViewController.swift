//
//  PVGPUViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/27/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import Defaults
import PVSettings
#if canImport(UIKit)
import UIKit
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
    #endif
    
    #if os(iOS)
    public override var prefersHomeIndicatorAutoHidden: Bool {
//        let shouldHideHomeIndicator: Bool = PVControllerManager.shared.hasControllers
//        return shouldHideHomeIndicator
        return true
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    #endif
}
