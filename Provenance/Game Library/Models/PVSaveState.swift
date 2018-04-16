//
//  PVSaveState.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
// import RealmSwift

@objcMembers public class PVSaveState: Object {

    dynamic var game: PVGame!
	dynamic var core: PVCore!
    dynamic var file: PVFile!
    dynamic var date: Date = Date()
	dynamic var lastOpened: Date?
    dynamic var image: PVImageFile?
    dynamic var isAutosave: Bool = false

	dynamic var createdWithCoreVersion: String!

	convenience init(withGame game: PVGame, core: PVCore, file: PVFile, image: PVImageFile? = nil, isAutosave: Bool = false) {
        self.init()
        self.game  = game
        self.file  = file
        self.image = image
        self.isAutosave = isAutosave
		self.core = core
		createdWithCoreVersion = core.projectVersion
    }

    class func delete(_ state: PVSaveState) throws {
        do {
            try FileManager.default.removeItem(at: state.file.url)
            if let image = state.image {
                try FileManager.default.removeItem(at: image.url)
            }

			let database = RomDatabase.sharedInstance
			try database.delete(state)
        } catch {
			throw error
		}
    }
}
