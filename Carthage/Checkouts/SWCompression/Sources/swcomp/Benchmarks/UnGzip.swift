// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class UnGzip: BenchmarkCommand {

    let name = "un-gzip"
    let shortDescription = "Performs benchmarking of GZip unarchiving using specified files"

    let files = CollectedParameter()

    let benchmarkName = "GZip Unarchive"
    let benchmarkFunction: (Data) throws -> Any = GzipArchive.unarchive

}
