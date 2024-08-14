//
//  PVCoreBridge.swift
//
//
//  Created by Joseph Mattiello on 5/18/24.
//

import Foundation
import PVAudio
import GameController
import PVLogging
import PVPlists

@_exported import MetalKit

public class PVBundleFinder {
    public static func bundle(forClass: AnyClass) -> Bundle {
        return Bundle(for: forClass)
    }
}
