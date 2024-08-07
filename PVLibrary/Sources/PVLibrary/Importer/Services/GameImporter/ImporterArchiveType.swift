//
//  ImporterArchiveType.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

public enum ImporterArchiveType: String, Codable, Equatable, Hashable, Sendable {
    case zip
    case gzip
    case sevenZip
    case rar

    var supportsCRCs: Bool { return true }
}
