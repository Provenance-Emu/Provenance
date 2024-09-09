//
//  ExtractionError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

enum ExtractionError: Error, Sendable, Codable, Hashable, Equatable {
    case unknownCompressionMethod
}
