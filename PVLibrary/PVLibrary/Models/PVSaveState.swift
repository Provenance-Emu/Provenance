//
//  PVSaveState.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import PVSupport

@objcMembers
public final class PVSaveState: Object {

    dynamic public var game: PVGame!
	dynamic public var core: PVCore!
    dynamic public var file: PVFile!
    dynamic public var date: Date = Date()
	dynamic public var lastOpened: Date?
    dynamic public var image: PVImageFile?
    dynamic public var isAutosave: Bool = false

	dynamic public var createdWithCoreVersion: String!

	public convenience init(withGame game: PVGame, core: PVCore, file: PVFile, image: PVImageFile? = nil, isAutosave: Bool = false) {
        self.init()
        self.game  = game
        self.file  = file
        self.image = image
        self.isAutosave = isAutosave
		self.core = core
		createdWithCoreVersion = core.projectVersion
    }

    public class func delete(_ state: PVSaveState) throws {
        do {
			// Temp store these URLs
			let fileURL = state.file.url
			let imageURl = state.image?.url

			let database = RomDatabase.sharedInstance
			try database.delete(state)

			try FileManager.default.removeItem(at: fileURL)
			if let imageURl = imageURl {
				try FileManager.default.removeItem(at: imageURl)
			}
        } catch {
			ELOG("Failed to delete PVState")
			throw error
		}
    }

	@objc dynamic public var isNewestAutosave : Bool {
		guard isAutosave, let game = game, let newestSave = game.autoSaves.first else {
			return false
		}

		let isNewest = newestSave == self
		return isNewest
	}

	public static func == (lhs: PVSaveState, rhs: PVSaveState) -> Bool {
		return lhs.file.url == rhs.file.url
	}
}
