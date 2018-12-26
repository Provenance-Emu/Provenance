// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class InfoTar: BenchmarkCommand {

    let name = "info-tar"
    let shortDescription = "Performs benchmarking of TAR info function using specified files"

    let files = CollectedParameter()

    let benchmarkName = "TAR info function"
    let benchmarkFunction: (Data) throws -> Any = TarContainer.info

}
