//
//  MetricKitCrashReportTests.swift
//  PVSwiftUITests
//

import Foundation
import Testing
@testable import PVSwiftUI

@Suite("MetricKitCrashReport")
struct MetricKitCrashReportTests {

    /// Shaped like `MXCallStackTree.jsonRepresentation()`: a root frame is the
    /// innermost call and `subFrames` are its callers.
    private let segfaultJSON = Data("""
    {
      "callStackPerThread": true,
      "callStacks": [
        {
          "threadAttributed": false,
          "callStackRootFrames": [
            {"binaryName": "libsystem_kernel.dylib", "binaryUUID": "K", "offsetIntoBinaryTextSegment": 3476, "address": 1}
          ]
        },
        {
          "threadAttributed": true,
          "callStackRootFrames": [
            {
              "binaryName": "libsystem_platform.dylib", "binaryUUID": "P", "offsetIntoBinaryTextSegment": 2808, "address": 2,
              "subFrames": [
                {
                  "binaryName": "PVCoreBridgeRetro", "binaryUUID": "R", "offsetIntoBinaryTextSegment": 347584, "address": 3,
                  "subFrames": [
                    {"binaryName": "virtualjaguar.libretro", "binaryUUID": "V", "offsetIntoBinaryTextSegment": 317520, "address": 4}
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
    """.utf8)

    private func segfault() -> MetricKitCrashReport {
        MetricKitCrashReport(
            callStackTreeJSON: segfaultJSON,
            exceptionType: 1,
            exceptionCode: 1,
            signal: 11,
            terminationReason: "Namespace SIGNAL, Code 11",
            build: "1792573983"
        )
    }

    @Test("Uses the attributed thread, innermost frame first")
    func flattensAttributedThread() {
        let names = segfault().frames.map(\.binaryName)
        #expect(names == ["libsystem_platform.dylib", "PVCoreBridgeRetro", "virtualjaguar.libretro"])
    }

    @Test("Culprit is the innermost frame in Provenance's own code")
    func culpritSkipsSystemFrames() {
        let report = segfault()
        #expect(report.culprit?.binaryName == "PVCoreBridgeRetro")
        #expect(report.culprit?.line == "PVCoreBridgeRetro +0x54dc0")
    }

    @Test("Names the signal and Mach exception")
    func labelsException() {
        let report = segfault()
        #expect(report.exceptionLabel == "SIGSEGV / EXC_BAD_ACCESS")
        #expect(report.title == "MetricKit crash: SIGSEGV / EXC_BAD_ACCESS in PVCoreBridgeRetro")
    }

    @Test("Fingerprint and tags identify the crash site and build")
    func fingerprintAndTags() {
        let report = segfault()
        #expect(report.fingerprint == ["metrickit-crash", "SIGSEGV / EXC_BAD_ACCESS", "PVCoreBridgeRetro +0x54dc0"])
        #expect(report.sentryTags["crash.binary"] == "PVCoreBridgeRetro")
        #expect(report.sentryTags["crash.build"] == "1792573983")
        #expect(report.sentryTags["crash.source"] == "metrickit")
    }

    @Test("Unknown numbers and unparseable JSON still produce a report")
    func toleratesMissingData() {
        let report = MetricKitCrashReport(
            callStackTreeJSON: Data("not json".utf8),
            exceptionType: 99,
            exceptionCode: nil,
            signal: nil,
            terminationReason: nil,
            build: nil
        )
        #expect(report.frames.isEmpty)
        #expect(report.culprit == nil)
        #expect(report.exceptionLabel == "no signal / exception 99")
        #expect(report.fingerprint.last == "no-frames")
        #expect(report.sentryTags["crash.build"] == nil)
    }
}
