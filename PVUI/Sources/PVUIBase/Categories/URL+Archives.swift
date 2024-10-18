//
//  URL+Archives.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import Foundation
import PVLibrary
import PVFileSystem

package extension URL {
    var isArchive: Bool {
        Extensions.archiveExtensions.contains(pathExtension.lowercased())
    }
}
