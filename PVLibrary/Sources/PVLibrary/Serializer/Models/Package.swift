//
//  Package.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public enum SerializerPackageType: String, Codable, Sendable {
    case game
    case saveState
    case config

    var `extension`: String {
        switch self {
        case .game: return "pvrom"
        case .saveState: return "psvsave"
        case .config: return "cfg"
        }
    }
}

public protocol Package: Codable, Sendable {
    associatedtype Metadata: Codable, Sendable
    var type: SerializerPackageType { get }
    var data: Data { get }
    var metadata: Metadata { get }
}
