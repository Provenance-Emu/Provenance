//
//  RealmActor.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

/// Actor isolated for accessing db in background thread safely
@globalActor
actor RealmActor: GlobalActor {
    static let shared = RealmActor()
}
