// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents file access permissions in UNIX format.
public struct Permissions: OptionSet {

    /// Raw bit flags value (in decimal).
    public let rawValue: UInt32

    /// Initializes permissions with bit flags in decimal.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Set UID.
    public static let setuid = Permissions(rawValue: 0o4000)

    /// Set GID.
    public static let setgid = Permissions(rawValue: 0o2000)

    /// Sticky bit.
    public static let sticky = Permissions(rawValue: 0o1000)

    /// Owner can read.
    public static let readOwner = Permissions(rawValue: 0o0400)

    /// Owner can write.
    public static let writeOwner = Permissions(rawValue: 0o0200)

    /// Owner can execute.
    public static let executeOwner = Permissions(rawValue: 0o0100)

    /// Group can read.
    public static let readGroup = Permissions(rawValue: 0o0040)

    /// Group can write.
    public static let writeGroup = Permissions(rawValue: 0o0020)

    /// Group can execute.
    public static let executeGroup = Permissions(rawValue: 0o0010)

    /// Others can read.
    public static let readOther = Permissions(rawValue: 0o0004)

    /// Others can write.
    public static let writeOther = Permissions(rawValue: 0o0002)

    /// Others can execute.
    public static let executeOther = Permissions(rawValue: 0o0001)

}
