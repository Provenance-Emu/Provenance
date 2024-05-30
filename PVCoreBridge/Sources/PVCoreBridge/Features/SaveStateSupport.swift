//
//  SaveStateSupport.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public enum SaveResult {
    case success
    case error(Error)
}

public protocol SaveStateSupport {
    func loadState(atPath: URL) -> SaveResult
    func saveState(toPath: URL) -> SaveResult
}

public protocol AsyncSaveStateSupport {
    func loadState(atPath: URL, completion: @escaping (SaveResult) -> Void) throws
    func saveState(toPath: URL, completion: @escaping (SaveResult) -> Void) throws
}
