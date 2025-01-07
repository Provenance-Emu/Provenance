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


public extension Notification.Name {
    static let themeDidChange = Notification.Name("com.provenance-emu.themeDidChange")
}

//import Perception
//
//#if !os(tvOS)
//@Observable
//#else
//@Perceptible
//#endif
public final class ThemeManager: ObservableObject {

    nonisolated(unsafe) public static let shared: ThemeManager = .init()
    private init() { }

    public var palettes: Array<any UXThemePalette> = []
    @Published
    public private(set) var currentPalette: any UXThemePalette = ProvenanceThemes.default.palette {
         didSet {
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
