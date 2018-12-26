// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class ZipCommand: ContainerCommand {

    let name = "zip"
    let shortDescription = "Extracts ZIP container"

    let info = Flag("-i", "--info", description: "Print list of entries in container and their attributes")
    let extract = Key<String>("-e", "--extract", description: "Extract container into specified directory")
    let verbose = Flag("-v", "--verbose", description: "Print the list of extracted files and directories.")

    let archive = Parameter()

    let openFunction: (Data) throws -> [ZipEntry] = ZipContainer.open
    let infoFunction: (Data) throws -> [ZipEntryInfo] = ZipContainer.info

}
