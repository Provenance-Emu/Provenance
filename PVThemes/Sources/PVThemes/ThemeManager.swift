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

    public var themes: Array<iOSTheme> = []
    public private(set) var currentTheme: iOSTheme = ProvenanceThemes.default.palette

    @MainActor
    public func setCurrentTheme(_ theme: iOSTheme) {
        // Set new value to obserable variable
        currentTheme = theme
        ThemeManager.applyTheme(self.currentTheme)
        Task { @MainActor in
            await UIApplication.shared.refreshAppearance(animated: true)
        }
    }

    @MainActor
    static weak var statusBarView: UIView?
}
