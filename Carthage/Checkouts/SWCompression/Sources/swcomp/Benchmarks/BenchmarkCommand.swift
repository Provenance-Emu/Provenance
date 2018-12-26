// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

#if os(Linux)
    import CoreFoundation
#endif

protocol BenchmarkCommand: Command {

    var files: CollectedParameter { get }

    var benchmarkName: String { get }

    var benchmarkFunction: (Data) throws -> Any { get }

}

extension BenchmarkCommand {

    func execute() throws {
        let title = "\(benchmarkName) Benchmark"
        print(title)
        print(String(repeating: "=", count: title.count))

        for file in self.files.value {
            print("File: \(file)\n")

            let inputURL = URL(fileURLWithPath: file)
            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)

            var totalTime: Double = 0

            var maxTime = Double(Int.min)
            var minTime = Double(Int.max)

            // Zeroth (excluded) iteration.
            print("Iteration 00 (excluded): ", terminator: "")
            #if !os(Linux)
                fflush(__stdoutp)
            #endif
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try benchmarkFunction(fileData)
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print(String(format: "%.3f", timeElapsed))

            for i in 1...10 {
                print(String(format: "Iteration %02u: ", i), terminator: "")
                #if !os(Linux)
                    fflush(__stdoutp)
                #endif
                let startTime = CFAbsoluteTimeGetCurrent()
                _ = try benchmarkFunction(fileData)
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print(String(format: "%.3f", timeElapsed))
                totalTime += timeElapsed
                if timeElapsed > maxTime {
                    maxTime = timeElapsed
                }
                if timeElapsed < minTime {
                    minTime = timeElapsed
                }
            }
            print(String(format: "\nAverage time: %.3f \u{B1} %.3f", totalTime / 10, (maxTime - minTime) / 2))
            print("---------------------------------------")
        }
    }

}
