//
//  EmulatorCoreSavesSerializerError.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 9/20/24.
//


public enum EmulatorCoreSavesSerializerError: Error {
    case fileNotFound
    case fileNotReadable
    case fileNotWritable
    case fileCorrupted
    case coreDoesNotSupportSaves
}
