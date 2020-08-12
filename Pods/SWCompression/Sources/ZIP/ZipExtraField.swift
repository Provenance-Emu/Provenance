// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import BitByteData

/// A type that represents an extra field from a ZIP container.
public protocol ZipExtraField {

    /**
     ID of extra field. Must be equal to the key of extra field in `ZipContainer.customExtraFields` dictionary and
     instance `id` property
     */
    static var id: UInt16 { get }

    /// Location of extra field. Must be equal to the value of `location` argument of `init?(_:_:location:)`.
    var location: ZipExtraFieldLocation { get }

    /// Size of extra field's data. Must be equal to the value of the second argument of `init?(_:_:location:)`.
    var size: Int { get }

    /**
     Creates an extra field instance reading `size` amount of data from `byteReader`.

     It is guaranteed that the offset of `byteReader` is equal to the position right after extra field header ID and
     length of extra field data. It is also guaranteed that header ID matches conforming type's static `id` property.

     Following conditions are checked after execution of this initializer. Failure to satisfy them in conforming type
     will result in runtime error.

     - Postcondition: `location` property of a created instance must be equal to the `location` argument.
     - Postcondition: `size` property of a created instance must be equal to the second argument.
     - Postcondition: exactly `size` amount of bytes must be read by initializer from `byteReader`.
     */
    init?(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation)

}

extension ZipExtraField {

    /**
     ID of extra field. Must be equal to the key of extra field in `ZipContainer.customExtraFields` dictionary and
     static `id` property
     */
    public var id: UInt16 {
        return Self.id
    }

}

/// Location of ZIP extra field inside a container.
public enum ZipExtraFieldLocation {
    /// ZIP extra field is located in container's Central Directory.
    case centralDirectory
    /// ZIP extra field is located in one of container's Local Headers.
    case localHeader
}
