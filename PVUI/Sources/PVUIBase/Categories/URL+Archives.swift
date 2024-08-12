//
//  URL+Archives.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import Foundation
import PVLibrary

package extension URL {
    var isArchive: Bool {
        PVEmulatorConfiguration.archiveExtensions.contains(pathExtension.lowercased())
    }
}
