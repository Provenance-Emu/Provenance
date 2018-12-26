// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides functions for work with TAR containers.
public class TarContainer: Container {

    /**
     Represents a "format" of TAR container: a minimal set of extensions to basic TAR format required to successfully
     read particular container.
     */
    public enum Format {
        /// Pre POSIX format (aka "basic TAR format").
        case prePosix
        /// "UStar" format introduced by POSIX IEEE P1003.1 standard.
        case ustar
        /// "UStar"-like format with GNU extensions (e.g. special container entries for long file and link names).
        case gnu
        /// "PAX" format introduced by POSIX.1-2001 standard, a set of extensions to "UStar" format.
        case pax
    }

    /**
     Processes TAR container and returns its "format": a minimal set of extensions to basic TAR format required to
     successfully read this container.

     - Parameter container: TAR container's data.

     - Throws: `TarError`, which may indicate that either container is damaged or it might not be TAR container at all.

     - SeeAlso: `TarContainer.Format`
     */
    public static func formatOf(container data: Data) throws -> Format {
        // TAR container should be at least 512 bytes long (when it contains only one header).
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }

        /// Object with input data which supports convenient work with bit shifts.
        var infoProvider = TarEntryInfoProvider(data)

        var ustarEncountered = false

        while let info = try infoProvider.next() {
            if info.specialEntryType == .globalExtendedHeader || info.specialEntryType == .localExtendedHeader {
                return .pax
            } else if info.specialEntryType == .longName || info.specialEntryType == .longLinkName {
                return .gnu
            } else {
                switch info.format {
                case .pax:
                    return .pax
                case .gnu:
                    return .gnu
                case .ustar:
                    ustarEncountered = true
                case .prePosix:
                    break
                }
            }
        }

        return ustarEncountered ? .ustar : .prePosix
    }

    /**
     Creates a new TAR container with `entries` as its content and generates container's `Data`.

     - Parameter entries: TAR entries to store in the container.

     - Throws: `TarCreateError.utf8NonEncodable` which indicates that one of the `TarEntryInfo`'s string properties
     (such as `name`) cannot be encoded with UTF-8 encoding.

     - SeeAlso: `TarEntryInfo` properties documenation to see how their values are connected with the specific TAR
     format used during container creation.
     */
    public static func create(from entries: [TarEntry]) throws -> Data {
        var out = Data()
        var extHeadersCount = 0
        for entry in entries {
            let extHeader = TarExtendedHeader(entry.info)
            let extHeaderData = try extHeader.generateContainerData()
            if !extHeaderData.isEmpty {
                var extHeaderInfo = TarEntryInfo(name: "SWC_PaxHeader_\(extHeadersCount)", type: .unknown)
                extHeaderInfo.specialEntryType = .localExtendedHeader
                extHeaderInfo.permissions = Permissions(rawValue: 420)
                extHeaderInfo.ownerID = entry.info.ownerID
                extHeaderInfo.groupID = entry.info.groupID
                extHeaderInfo.modificationTime = Date()

                let extHeaderEntry = TarEntry(info: extHeaderInfo, data: extHeaderData)
                try out.append(extHeaderEntry.generateContainerData())

                extHeadersCount += 1
            }
            try out.append(entry.generateContainerData())
        }
        out.append(Data(count: 1024))
        return out
    }

    /**
     Processes TAR container and returns an array of `TarEntry` with information and data for all entries.

     - Important: The order of entries is defined by TAR container and, particularly, by the creator of a given TAR
     container. It is likely that directories will be encountered earlier than files stored in those directories, but no
     particular order is guaranteed.

     - Parameter container: TAR container's data.

     - Throws: `TarError`, which may indicate that either container is damaged or it might not be TAR container at all.

     - Returns: Array of `TarEntry`.
     */
    public static func open(container data: Data) throws -> [TarEntry] {
        let infos = try info(container: data)
        var entries = [TarEntry]()

        for entryInfo in infos {
            if entryInfo.type == .directory {
                var entry = TarEntry(info: entryInfo, data: nil)
                entry.info.size = 0
                entries.append(entry)
            } else {
                let dataStartIndex = entryInfo.blockStartIndex + 512
                let dataEndIndex = dataStartIndex + entryInfo.size!
                let entryData = data.subdata(in: dataStartIndex..<dataEndIndex)
                entries.append(TarEntry(info: entryInfo, data: entryData))
            }
        }

        return entries
    }

    /**
     Processes TAR container and returns an array of `TarEntryInfo` with information about entries in this container.

     - Important: The order of entries is defined by TAR container and, particularly, by the creator of a given TAR
     container. It is likely that directories will be encountered earlier than files stored in those directories, but no
     particular order is guaranteed.

     - Parameter container: TAR container's data.

     - Throws: `TarError`, which may indicate that either container is damaged or it might not be TAR container at all.

     - Returns: Array of `TarEntryInfo`.
     */
    public static func info(container data: Data) throws -> [TarEntryInfo] {
        // First, if the TAR container contains only header, it should be at least 512 bytes long.
        // So we have to check this.
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }

        /// Object with input data which supports convenient work with bit shifts.
        var infoProvider = TarEntryInfoProvider(data)
        var entries = [TarEntryInfo]()

        while let info = try infoProvider.next() {
            guard info.specialEntryType == nil
                else { continue }
            entries.append(info)
        }

        return entries
    }

}
