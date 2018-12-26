// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class InfoZip: BenchmarkCommand {

    let name = "info-zip"
    let shortDescription = "Performs benchmarking of ZIP info function using specified files"

    let files = CollectedParameter()

    let benchmarkName = "ZIP info function"
    let benchmarkFunction: (Data) throws -> Any = ZipContainer.info

}
