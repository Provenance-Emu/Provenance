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

    public static func values(fromArray a: [[String]]) -> [CoreOptionMultiValue] {
        return a.compactMap {
            if $0.count == 1 {
                return .init(title: $0[0], description: nil)
            } else if $0.count >= 2 {
                return .init(title: $0[0], description: $0[1])
            } else {
                return nil
            }
        }
    }

    public static func values(fromArray a: [String]) -> [CoreOptionMultiValue] {
        return a.map {
            .init(title: $0, description: nil)
        }
    }
}

extension CoreOptionMultiValue: Codable, Equatable, Hashable {}
extension CoreOptionMultiValue {
    public init(title: String, description: String) {
        self.title = title
        self.description = description
    }

    public init(_ title: String, _ description: String) {
        self.title = title
        self.description = description
    }
}
