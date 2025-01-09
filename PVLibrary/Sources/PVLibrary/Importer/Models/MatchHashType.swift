//
//  MatchHashType.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

package enum MatchHashType: String, Codable, Equatable, Hashable, Sendable {
    case MD5
    case CRC
    case SHA1
}
