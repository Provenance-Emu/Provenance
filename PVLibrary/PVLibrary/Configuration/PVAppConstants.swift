//
//  PVAppConstants.swift
//  Provenance
//
//  Created by David Muzi on 2015-12-16.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import Foundation

public let PVMaxRecentsShortcutCount: Int = 4
public let PVAppGroupId = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String ?? "group.org.provenance-emu.provenance"
public let kInterfaceDidChangeNotification = "kInterfaceDidChangeNotification"
public let PVGameControllerKey = "PlayController"
public let PVGameMD5Key = "md5"
public let PVAppURLKey = "provenance"
public let UbiquityIdentityTokenKey = (Bundle.main.bundleIdentifier ?? "org.provenance-emu.provenance")  + ".UbiquityIdentityToken"

#if os(tvOS)
    public let PVThumbnailMaxResolution: Float = 800.0
#else
    public let PVThumbnailMaxResolution: Float = 200.0
#endif
