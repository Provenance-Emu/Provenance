//
//  SaveStateUpdateError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

enum SaveStateUpdateError: Error {
    case failedToConvertToString
    case missingOpeningCurlyBrace
    case missingCoreKey
    case errorConvertingStringToBinary
}
