// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class Info7z: BenchmarkCommand {

    let name = "info-7z"
    let shortDescription = "Performs benchmarking of 7-Zip info function using specified files"

    let files = CollectedParameter()

    let benchmarkName = "7-Zip info function"
    let benchmarkFunction: (Data) throws -> Any = SevenZipContainer.info

}
