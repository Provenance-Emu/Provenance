//
//  PVAppConstants.swift
//  Provenance
//
//  Created by David Muzi on 2015-12-16.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import Foundation
import PVPrimitives

public let PVMaxRecentsShortcutCount: Int = 4
public let kInterfaceDidChangeNotification = "kInterfaceDidChangeNotification"
public let PVGameControllerKey = "PlayController"
public let PVGameMD5Key = "md5"
public let PVAppURLKey = ProvenanceDeepLink.scheme
public let PVLibraryScreenPath = "screen/library"
public let PVLibraryScreenURI = ProvenanceDeepLink.libraryScreenURI
public let PVLibraryScreenURL = ProvenanceDeepLink.libraryScreenURL

/// Builds a deep-link URI for opening a game by MD5.
/// - Parameter md5: MD5 identifier for the game.
/// - Returns: URI string in `provenance://open?md5=<value>` format.
public func PVOpenGameMD5URI(_ md5: String) -> String {
    ProvenanceDeepLink.openGameMD5URI(md5)
}
