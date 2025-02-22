//
//  PVSaveState.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift
import PVLogging
import PVPrimitives

@objcMembers
public final class PVSaveState: RealmSwift.Object, Identifiable, Filed, LocalFileProvider {
    @Persisted(wrappedValue: UUID().uuidString, primaryKey: true) public var id: String
    @Persisted public var game: PVGame!
    @Persisted public var core: PVCore!
    @Persisted public var file: PVFile?
    @Persisted public var date: Date = Date()
    @Persisted public var lastOpened: Date?
    @Persisted public var image: PVImageFile?
    @Persisted public var isAutosave: Bool = false

    @Persisted public var isPinned: Bool = false
    @Persisted public var isFavorite: Bool = false
    
    @Persisted public var userDescription: String? = nil

    @Persisted public var createdWithCoreVersion: String!

    public convenience init(withGame game: PVGame, core: PVCore, file: PVFile, date: Date = Date(), image: PVImageFile? = nil, isAutosave: Bool = false, isPinned: Bool = false, isFavorite: Bool = false, userDescription: String? = nil, createdWithCoreVersion: String? = nil) {
        self.init()
        self.game = game
        self.file = file
        self.image = image
        self.date = date
        self.isAutosave = isAutosave
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.userDescription = userDescription
        self.core = core
        self.createdWithCoreVersion = createdWithCoreVersion ?? core.projectVersion
    }

    public static func == (lhs: PVSaveState, rhs: PVSaveState) -> Bool {
        return lhs.file?.url == rhs.file?.url
    }
}

public extension PVSaveState {
    var size: UInt64 {
        (file?.size ?? 0) + (image?.size ?? 0)
    }
}
