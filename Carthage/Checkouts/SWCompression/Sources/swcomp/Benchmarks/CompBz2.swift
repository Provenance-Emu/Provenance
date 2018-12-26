// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class CompBz2: BenchmarkCommand {

    let name = "comp-bz2"
    let shortDescription = "Performs benchmarking of BZip2 compression using specified files"

    let files = CollectedParameter()

    let benchmarkName = "BZip2 Compression"
    let benchmarkFunction: (Data) throws -> Any = BZip2.compress

}
