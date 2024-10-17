//
//  PVCoreBridge.swift
//
//
//  Created by Joseph Mattiello on 5/18/24.
//

import Foundation
import PVAudio
import PVLogging
import PVPlists

public class PVBundleFinder {
    public static func bundle(forClass: AnyClass) -> Bundle {
        return Bundle(for: forClass)
    }
}
