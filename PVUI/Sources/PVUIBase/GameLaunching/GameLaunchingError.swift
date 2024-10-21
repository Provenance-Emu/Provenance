//
//  GameLaunchingError.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import Foundation

public enum GameLaunchingError: Error {
    case systemNotFound
    case generic(String)
    case missingBIOSes([String])
}
