//
//  CoreOptionEnumValue.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public struct CoreOptionEnumValue: Sendable {
    public let title: String
    public let description: String?
    public let value: Int

    public init(title: String, description: String? = nil, value: Int) {
        self.title = title
        self.description = description
        self.value = value
    }
}

extension CoreOptionEnumValue {
    public static func values(fromArray a: [[String]]) -> [CoreOptionEnumValue] {
        return a.enumerated().compactMap {
            if $0.element.count == 1 {
                return .init(title: $0.element[0], description: nil, value: $0.offset)
            } else if $0.element.count >= 2 {
                return .init(title: $0.element[0], description: $0.element[1], value: $0.offset)
            } else {
                return nil
            }
        }
    }

    public static func values(fromArray a: [String]) -> [CoreOptionEnumValue] {
        return a.enumerated().map {
            .init(title: $0.element, description: nil, value: $0.offset)
        }
    }
}

extension CoreOptionEnumValue: Codable, Equatable, Hashable {}
