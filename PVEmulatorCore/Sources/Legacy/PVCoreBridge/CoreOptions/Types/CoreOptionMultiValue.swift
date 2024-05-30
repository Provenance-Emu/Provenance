//
//  CoreOptionMultiValue.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public struct CoreOptionMultiValue {
    public let title: String
    public let description: String?
    public let isDefault: Bool

    public static func values(fromArray a: [[String]]) -> [CoreOptionMultiValue] {
        return a.compactMap {
            if $0.count == 1 {
                return .init(title: $0[0], description: nil, isDefault: false)
            } else if $0.count >= 2 {
                return .init(title: $0[0], description: $0[1])
            } else {
                return nil
            }
        }
    }

    public static func values(fromArray a: [String]) -> [CoreOptionMultiValue] {
        return a.map {
            .init(title: $0, description: nil, isDefault: false)
        }
    }
}

extension CoreOptionMultiValue: Codable, Equatable, Hashable {}
extension CoreOptionMultiValue {
    public init(title: String, description: String, isDefault: Bool = false) {
        self.title = title
        self.description = description
        self.isDefault = isDefault
    }

    public init(_ title: String, _ description: String) {
        self.title = title
        self.description = description
        self.isDefault = false
    }
}
