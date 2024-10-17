//
//  Error.swift
//  
//
//  Created by Drew McCormack on 25/06/2022.
//

import Foundation

public enum Error: Swift.Error, Sendable {
    case couldNotAccessUbiquityContainer
    case queriedWhileNotConnected
    case rootDirectoryURLIsNotDirectory
    case notSignedIntoCloud
    case invalidMetadata
    case invalidFileType
    case foundationError(NSError)
}
