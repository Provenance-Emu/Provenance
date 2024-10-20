//
//  ConflictsController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/29/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLibrary
import PVPrimitives
import RxSwift
import RxCocoa

//public struct Conflict {
//    let path: URL
//    let candidates: [System]
//}

public protocol ConflictsController: AnyObject {
    typealias ConflictItem = (path: URL, candidates: [System])
    
    var conflicts: [ConflictItem] { get }
    
    func resolveConflicts(withSolutions: [URL: System]) async
    func deleteConflict(path: URL) async
    func updateConflicts() async
}
