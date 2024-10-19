//
//  EmulatorCoreSavesSerializer.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

@objc public protocol EmulatorCoreSavesSerializer {
    typealias SaveStateCompletion = (Error?) -> Void

    @objc(saveStateToFileAtPath:error:)
    func saveStateSync(toFileAtPath path: String) throws
    @objc(loadStateToFileAtPath:error:)
    func loadStateSync(toFileAtPath path: String) throws

#warning("Finish this async wrapper")
//    func saveState(toFileAtPath fileName: String,
//                   completionHandler block: SaveStateCompletion)
//
//    func loadState(fromFileAtPath fileName: String,
//                   completionHandler block: SaveStateCompletion)

    func saveState(toFileAtPath path: String) async throws
    func loadState(fromFileAtPath path: String) async throws

    //    typealias SaveCompletion = (Bool, Error)
    //
    //    func saveState(toFileAtPath path: String, completionHandler completion: SaveCompletion)
    //    func loadState(toFileAtPath path: String, completionHandler completion: SaveCompletion)
}

public extension EmulatorCoreSavesSerializer where Self: ObjCBridgedCore, Self.Bridge: EmulatorCoreSavesSerializer {
    
    func saveStateSync(toFileAtPath path: String) throws {
        try bridge.saveStateSync(toFileAtPath: path)
    }

    func loadStateSync(toFileAtPath path: String) throws {
        try bridge.loadStateSync(toFileAtPath: path)
    }

    // Helpers
    func saveState(toFileAtPath path: String) async throws {
        try await self.saveStateSync(toFileAtPath: path)
    }
    
    func loadState(fromFileAtPath path: String) async throws {
        try await self.loadStateSync(toFileAtPath: path)
    }
}
