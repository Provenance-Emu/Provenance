//
//  Package.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public enum SerializerPackageType: String, Codable {
    case game
    case saveState

    var `extension`: String {
        switch self {
        case .game: return "pvrom"
        case .saveState: return "psvsave"
        }
    }
}

public protocol Package: Codable {
    associatedtype Metadata: Codable
    var type: SerializerPackageType { get }
    var data: Data { get }
    var metadata: Metadata { get }
}
