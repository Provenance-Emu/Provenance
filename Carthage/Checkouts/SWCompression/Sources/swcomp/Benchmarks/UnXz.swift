// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class UnXz: BenchmarkCommand {

    let name = "un-xz"
    let shortDescription = "Performs benchmarking of XZ unarchiving using specified files"

    let files = CollectedParameter()

    let benchmarkName = "XZ Unarchive"
    let benchmarkFunction: (Data) throws -> Any = XZArchive.unarchive

}
