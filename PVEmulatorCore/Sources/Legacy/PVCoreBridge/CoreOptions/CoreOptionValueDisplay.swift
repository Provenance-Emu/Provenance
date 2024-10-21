//
//  CoreOptions+Types.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public struct CoreOptionValueDisplay {
    public let title: String
    public let description: String?
    public let requiresRestart: Bool

    public init(title: String, description: String? = nil, requiresRestart: Bool = false) {
        self.title = title
        self.description = description
        self.requiresRestart = requiresRestart
    }
}

extension CoreOptionValueDisplay: Codable, Equatable, Hashable {}
