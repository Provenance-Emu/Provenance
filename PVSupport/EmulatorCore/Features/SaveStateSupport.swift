//
//  SaveStateSupport.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public enum Result {
    case success
    case error(Error)
}

public protocol SaveStateSupport {
    func loadState(atPath: URL) -> Result
    func saveState(toPath: URL) -> Result
}

public protocol AsyncSaveStateSupport {
    func loadState(atPath: URL, completion: @escaping (Result) -> Void) throws
    func saveState(toPath: URL, completion: @escaping (Result) -> Void) throws
}
