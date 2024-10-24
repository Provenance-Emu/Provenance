//
//  GameLaunchingAppDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/27/24.
//

#if canImport(UIKit)

import UIKit
import PVLibrary


public protocol GameLaunchingAppDelegate: UIApplicationDelegate {
    var shortcutItemGame: PVGame? { get set }
}

#elseif canImport(AppKit)

import AppKit
import PVLibrary

public protocol GameLaunchingAppDelegate: NSApplicationDelegate {
    var shortcutItemGame: PVGame? { get set }
}

#endif
