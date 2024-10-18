//
//  MatchType.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

enum MatchType: Sendable {
    case byExtension
    case byHash(MatchHashType)
    case byFolder
    case manually
}
