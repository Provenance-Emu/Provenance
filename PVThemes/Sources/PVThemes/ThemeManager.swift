//
//  ThemeManager.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/8/18.
//  Copyright © 2024 Joseph Mattiello. All rights reserved.
//

import Foundation
import SwiftMacros
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

//@Singleton
@available(macOS 14.0, *)
@Observable
public final class ThemeManager {

    nonisolated(unsafe) public static let shared: ThemeManager = .init()
    private init() { }

    public let themes: Array<iOSTheme> = []
    public private(set) var currentTheme: iOSTheme = ProvenanceThemes.default.palette

    public func setCurrentTheme(_ theme: iOSTheme) {
        // Set new value to obserable variable
        currentTheme = theme
        Task {
            await UIApplication.shared.refreshAppearance(animated: true)
        }
    }

    @MainActor
    static weak var statusBarView: UIView?
}
