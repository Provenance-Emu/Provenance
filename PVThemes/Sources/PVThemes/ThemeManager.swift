//
//  ThemeManager.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/8/18.
//  Copyright © 2024 Joseph Mattiello. All rights reserved.
//

import Foundation
import SwiftMacros
import Observation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import PVSettings

//@Singleton
@Observable
public final class ThemeManager: ObservableObject {

    nonisolated(unsafe) public static let shared: ThemeManager = .init()
    private init() { }

    public var palettes: Array<any UXThemePalette> = []
    public private(set) var currentPalette: any UXThemePalette = ProvenanceThemes.default.palette

    @MainActor
    public func setCurrentPalette(_ palatte: any UXThemePalette) {
        // Set new value to obserable variable
        currentPalette = palatte
        ThemeManager.applyPalette(palatte)
        Task { @MainActor in
            await UIApplication.shared.refreshAppearance(animated: true)
        }
    }

    @MainActor
    static weak var statusBarView: UIView?
}
