//
//  PVFiled.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 7/23/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift

public protocol PVFiled {
	var file: PVFile? { get }
}

public extension PVFiled where Self : Object {
	var missing: Bool {
		return file == nil || file!.missing
	}

	var md5: String? {
		guard let file = file else {
			return nil
		}
		return file.md5
	}
}
