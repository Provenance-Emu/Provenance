// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that represents a container with files, directories and/or other data.
public protocol Container {

    /// A type that represents an entry from this container.
    associatedtype Entry: ContainerEntry

    /// Retrieve all container entries with their data.
    static func open(container: Data) throws -> [Entry]

    /// Retrieve information about all container entries (without their data).
    static func info(container: Data) throws -> [Entry.Info]

}
