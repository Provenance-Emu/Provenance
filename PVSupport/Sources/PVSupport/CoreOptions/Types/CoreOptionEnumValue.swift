//
//  CoreOptionEnumValue.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public struct CoreOptionEnumValue {
    public let title: String
    public let description: String?
    public let value: Int

    public init(title: String, description: String? = nil, value: Int) {
        self.title = title
        self.description = description
        self.value = value
    }
}

extension CoreOptionEnumValue: Codable, Equatable, Hashable {}
