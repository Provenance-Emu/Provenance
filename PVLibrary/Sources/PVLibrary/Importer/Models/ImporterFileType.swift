//
//  ImporterFileType.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

public enum ImporterFileType: Sendable {
    case rom
    case image
    case package(SerializerPackageType)
    case archive(ImporterArchiveType)
    case unknown
}
