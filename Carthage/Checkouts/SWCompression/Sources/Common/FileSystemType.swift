// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents type of the file system on which an archive or container was created.
 File system determines meaning of file attributes.
 */
public enum FileSystemType {
    /// FAT filesystem.
    case fat
    /// Filesystem of older Macintosh systems.
    case macintosh
    /// NTFS.
    case ntfs
    /// Other/unknown file system.
    case other
    /**
     One of many file systems of UNIX-like OS.

     - Note: Modern macOS systems also fall into this category.
     */
    case unix
}
