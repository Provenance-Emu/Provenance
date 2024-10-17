//
//  CheatsSection.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import PVLibrary
import RealmSwift

struct CheatsSection {
    let title: String
    let saves: Results<PVCheats>
}
