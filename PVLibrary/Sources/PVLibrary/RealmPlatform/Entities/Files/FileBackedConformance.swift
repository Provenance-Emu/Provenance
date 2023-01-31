//
//  FileBacked.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 7/23/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift

public extension FileBacked where Self: Object {
    var online: Bool {
        return fileInfo != nil || fileInfo!.online
    }

    var md5: String? {
        guard let file = fileInfo else {
            return nil
        }
        return file.md5
    }
}
