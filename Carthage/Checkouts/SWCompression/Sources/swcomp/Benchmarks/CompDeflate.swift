// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class CompDeflate: BenchmarkCommand {

    let name = "comp-deflate"
    let shortDescription = "Performs benchmarking of Deflate compression using specified files"

    let files = CollectedParameter()

    let benchmarkName = "Deflate Compression"
    let benchmarkFunction: (Data) throws -> Any = Deflate.compress

}
