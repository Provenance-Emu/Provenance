//
//  EmulatorCoreSavesSerializer.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

public enum EmulatorCoreSavesSerializerError: Error {
    case fileNotFound
    case fileNotReadable
    case fileNotWritable
    case fileCorrupted
    case coreDoesNotSupportSaves
}

@objc public protocol EmulatorCoreSavesSerializer {
    typealias SaveStateCompletion = (Bool, Error?) -> Void

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
