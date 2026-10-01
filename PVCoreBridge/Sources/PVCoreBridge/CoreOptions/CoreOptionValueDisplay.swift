//
//  CoreOptions+Types.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public struct CoreOptionValueDisplay: Sendable {
    public let title: String
    public let description: String?
    public let requiresRestart: Bool
    /// Identity used to persist the option, for cores whose `title` is display
    /// text rather than a stable, unique name (libretro: `desc` is what the
    /// user reads, the option `key` is what identifies it).
    ///
    /// `nil` keeps the historical behaviour of keying storage by `title`.
    public let storageKey: String?

    public init(title: String, description: String? = nil, requiresRestart: Bool = false, storageKey: String? = nil) {
        self.title = title
        self.description = description
        self.requiresRestart = requiresRestart
        self.storageKey = storageKey
    }
}

extension CoreOptionValueDisplay: Codable, Equatable, Hashable {}
