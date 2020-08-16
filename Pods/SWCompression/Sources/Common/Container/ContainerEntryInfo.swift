// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that provides access to information about an entry from the container.
public protocol ContainerEntryInfo {

    /// Entry's name.
    var name: String { get }

    /// Entry's type.
    var type: ContainerEntryType { get }

    /// Entry's data size (can be `nil` if either data or size aren't available).
    var size: Int? { get }

    /// Entry's last access time (`nil`, if not available).
    var accessTime: Date? { get }

    /// Entry's creation time (`nil`, if not available).
    var creationTime: Date? { get }

    /// Entry's last modification time (`nil`, if not available).
    var modificationTime: Date? { get }

    /// Entry's permissions in POSIX format (`nil`, if not available).
    var permissions: Permissions? { get }

}
