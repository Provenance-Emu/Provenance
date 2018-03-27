//
//  PVAppConstants.swift
//  Provenance
//
//  Created by David Muzi on 2015-12-16.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import Foundation

public let PVMaxRecentsShortcutCount: Int = 4
public let PVAppGroupId                    = "group.provenance-emu.provenance"
public let kInterfaceDidChangeNotification = "kInterfaceDidChangeNotification"
public let PVGameControllerKey             = "PlayController"
public let PVGameMD5Key                    = "md5"
public let PVAppURLKey                     = "provenance"

#if os(tvOS)
public let PVThumbnailMaxResolution: Float = 400.0
#else
public let PVThumbnailMaxResolution: Float = 200.0
#endif

public func PVMaxRecentsCount() -> Int {
#if os(tvOS)
    return 12
#elseif os(iOS)
    #if EXTENSION
        return 9
    #else
    return UIApplication.shared.keyWindow?.traitCollection.userInterfaceIdiom == .phone ? 6 : 9
    #endif
#endif
}
