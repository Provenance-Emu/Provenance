//
//  ImporterFileType.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation
import PVPatching

public enum ImporterFileType: Sendable {
    case rom
    case image
    case package(SerializerPackageType)
    case archive(ImporterArchiveType)
    case patch(PatchFormat)
    case unknown
}
