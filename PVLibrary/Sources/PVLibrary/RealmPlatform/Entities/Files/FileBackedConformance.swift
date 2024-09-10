//
//  FileBacked.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 7/23/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift
import PVLibraryPrimitives

public extension FileBacked where Self: RealmSwift.Object {
    var online: Bool { get {
        guard let fileInfo = fileInfo else { return false }
        return fileInfo.online
    }}

    var md5: String? { get {
        guard let file = fileInfo else {
            return nil
        }
        return file.md5
    }}
}
