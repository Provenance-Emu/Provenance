// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SwiftCLI

class BenchmarkGroup: CommandGroup {

    let name = "benchmark"
    let shortDescription = "Commands for benchmarking"

    let children: [Routable] = [UnGzip(), UnXz(), UnBz2(), InfoTar(), InfoZip(), Info7z(), CompDeflate(), CompBz2()]

}
