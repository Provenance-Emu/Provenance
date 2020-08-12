// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

/**
 Represents an error which happened during the creation of a new TAR container.

 - Note: This error type is going to be merged with `TarError` in the next major update.
 */
public enum TarCreateError: Error {
    /// One of the `TarEntryInfo`'s string properties (such as `name`) cannot be encoded with UTF-8 encoding.
    case utf8NonEncodable
}
