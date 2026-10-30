//
//  ThemeManager.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/8/18.
//  Copyright © 2024 Joseph Mattiello. All rights reserved.
//

import Foundation
import Observation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import PVSettings


public extension Notification.Name {
    static let themeDidChange = Notification.Name("com.provenance-emu.themeDidChange")
}

// @Observable
public final class ThemeManager: ObservableObject {

    nonisolated(unsafe) public static let shared: ThemeManager = .init()
    private init() { }

    private let colorPaletteLock = NSLock()
    private var colorPalette: any UXThemePalette = ProvenanceThemes.default.palette

    /// A synchronized snapshot for dynamic UIColor providers, which can resolve off the main thread.
    public var paletteForColorResolution: any UXThemePalette {
        colorPaletteLock.lock()
        defer { colorPaletteLock.unlock() }
        return colorPalette
    }

    public var palettes: Array<any UXThemePalette> = []
    @Published
    public private(set) var currentPalette: any UXThemePalette = ProvenanceThemes.default.palette {
         didSet {
             colorPaletteLock.lock()
             colorPalette = currentPalette
             colorPaletteLock.unlock()
             if currentPalette.name != oldValue.name {
                 Task { @MainActor in
                     NotificationCenter.default.post(name: .themeDidChange, object: nil)
                 }
             }
         }
     }

    @MainActor
    public func setCurrentPalette(_ palatte: any UXThemePalette) {
        // Set new value to obserable variable
        currentPalette = palatte
        ThemeManager.applyPalette(palatte)
        Task { @MainActor in
            UIApplication.shared.refreshAppearance(animated: true)
        }
    }

    @MainActor
    static weak var statusBarView: UIView?
}
