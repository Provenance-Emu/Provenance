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
    var online: Bool { get async {
        guard let fileInfo = fileInfo else { return false }
        return await fileInfo.online
    }}

    var md5: String? { get async {
        guard let file = fileInfo else {
            return nil
        }
        return await file.md5
    }}
}
