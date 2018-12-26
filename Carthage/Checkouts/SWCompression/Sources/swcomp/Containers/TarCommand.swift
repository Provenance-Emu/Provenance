// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class TarCommand: Command {

    let name = "tar"
    let shortDescription = "Extracts TAR container"

    let gz = Flag("-z", "--gz", description: "Decompress with GZip first")
    let bz2 = Flag("-j", "--bz2", description: "Decompress with BZip2 first")
    let xz = Flag("-x", "--xz", description: "Decompress with XZ first")

    let info = Flag("-i", "--info", description: "Print list of entries in container and their attributes")
    let extract = Key<String>("-e", "--extract", description: "Extract container into specified directory")
    let format = Flag("-f", "--format", description: "Print \"format\" of the container")
    let create = Key<String>("-c", "--create",
                             description: "Create a new container containing specified file/directory (recursively)")

    let verbose = Flag("-v", "--verbose", description: "Print the list of extracted files and directories.")

    var optionGroups: [OptionGroup] {
        let compressions = OptionGroup(options: [gz, bz2, xz], restriction: .atMostOne)
        let actions = OptionGroup(options: [info, extract, format, create], restriction: .exactlyOne)
        return [compressions, actions]
    }

    let archive = Parameter()

    func execute() throws {
        var fileData: Data
        if self.create.value == nil {
            fileData = try Data(contentsOf: URL(fileURLWithPath: self.archive.value),
                                    options: .mappedIfSafe)

            if gz.value {
                fileData = try GzipArchive.unarchive(archive: fileData)
            } else if bz2.value {
                fileData = try BZip2.decompress(data: fileData)
            } else if xz.value {
                fileData = try XZArchive.unarchive(archive: fileData)
            }
        } else {
            fileData = Data()
        }

        if info.value {
            let entries = try TarContainer.info(container: fileData)
            swcomp.printInfo(entries)
        } else if let outputPath = self.extract.value {
            if try !isValidOutputDirectory(outputPath, create: true) {
                print("ERROR: Specified path already exists and is not a directory.")
                exit(1)
            }

            let entries = try TarContainer.open(container: fileData)
            try swcomp.write(entries, outputPath, verbose.value)
        } else if format.value {
            let format = try TarContainer.formatOf(container: fileData)
            switch format {
            case .prePosix:
                print("TAR format: pre-POSIX")
            case .ustar:
                print("TAR format: POSIX aka \"ustar\"")
            case .gnu:
                print("TAR format: POSIX with GNU extensions")
            case .pax:
                print("TAR format: PAX")
            }
        } else if let inputPath = self.create.value {
            let fileManager = FileManager.default

            guard !fileManager.fileExists(atPath: self.archive.value) else {
                print("ERROR: Output path already exists.")
                exit(1)
            }

            if gz.value || bz2.value || xz.value {
                print("Warning: compression options are unsupported and ignored when creating new container.")
            }

            guard fileManager.fileExists(atPath: inputPath) else {
                print("ERROR: Specified path doesn't exist.")
                exit(1)
            }
            if verbose.value {
                print("Creating new container at \"\(self.archive.value)\" from \"\(inputPath)\"")
                print("d = directory, f = file, l = symbolic link")
            }
            let entries = try self.createEntries(inputPath, verbose.value)
            let containerData = try TarContainer.create(from: entries)
            try containerData.write(to: URL(fileURLWithPath: self.archive.value))
        }
    }

    private func createEntries(_ inputPath: String, _ verbose: Bool) throws -> [TarEntry] {
        let inputURL = URL(fileURLWithPath: inputPath)
        let fileManager = FileManager.default

        let fileAttributes = try fileManager.attributesOfItem(atPath: inputPath)

        let name = inputURL.relativePath

        let entryType: ContainerEntryType
        if let typeFromAttributes = fileAttributes[.type] as? FileAttributeType {
            switch typeFromAttributes {
            case .typeBlockSpecial:
                entryType = .blockSpecial
            case .typeCharacterSpecial:
                entryType = .characterSpecial
            case .typeDirectory:
                entryType = .directory
            case .typeRegular:
                entryType = .regular
            case .typeSocket:
                entryType = .socket
            case .typeSymbolicLink:
                entryType = .symbolicLink
            case .typeUnknown:
                entryType = .unknown
            default:
                entryType = .unknown
            }
        } else {
            entryType = .unknown
        }

        var info = TarEntryInfo(name: name, type: entryType)
        info.creationTime = fileAttributes[.creationDate] as? Date
        info.groupID = (fileAttributes[.groupOwnerAccountID] as? NSNumber)?.intValue
        info.ownerGroupName = fileAttributes[.groupOwnerAccountName] as? String
        info.modificationTime = fileAttributes[.modificationDate] as? Date
        info.ownerID = (fileAttributes[.ownerAccountID] as? NSNumber)?.intValue
        info.ownerUserName = fileAttributes[.ownerAccountName] as? String
        if let posixPermissions = (fileAttributes[.posixPermissions] as? NSNumber)?.intValue {
            info.permissions = Permissions(rawValue: UInt32(truncatingIfNeeded: posixPermissions))
        }

        var entryData = Data()
        if entryType == .symbolicLink {
            info.linkName = try fileManager.destinationOfSymbolicLink(atPath: inputPath)
        } else if entryType != .directory {
            entryData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        }

        if verbose {
            var log = ""
            switch entryType {
            case .regular:
                log += "f: "
            case .directory:
                log += "d: "
            case .symbolicLink:
                log += "l:"
            default:
                log += "u: "
            }
            log += name
            if entryType == .symbolicLink {
                log += " -> " + info.linkName
            }
            print(log)
        }

        let entry = TarEntry(info: info, data: entryData)

        var entries = [TarEntry]()
        entries.append(entry)

        if entryType == .directory {
            for subPath in try fileManager.contentsOfDirectory(atPath: inputPath) {
                entries.append(contentsOf: try self.createEntries(inputURL.appendingPathComponent(subPath).relativePath,
                                                                  verbose))
            }
        }

        return entries
    }

}
