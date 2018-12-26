// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class UnBz2: BenchmarkCommand {

    let name = "un-bz2"
    let shortDescription = "Performs benchmarking of BZip2 unarchiving using specified files"

    let files = CollectedParameter()

    let benchmarkName = "BZip2 Unarchive"
    let benchmarkFunction: (Data) throws -> Any = BZip2.decompress

}
