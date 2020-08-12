// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that represents an entry from the container with its data and information.
public protocol ContainerEntry {

    /// A type that provides information about an entry.
    associatedtype Info: ContainerEntryInfo

    /// Provides access to information about the entry.
    var info: Info { get }

    /**
     Entry's data (`nil` if entry is a directory or data isn't available).

     - Note: It is assumed that the compression provided by the container is yet to be applied to data.
     */
    var data: Data? { get }

}
