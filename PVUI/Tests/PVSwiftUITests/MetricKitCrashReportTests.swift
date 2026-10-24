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

    @Test("Reads the documented shape with a callStackTree wrapper")
    func flattensWrappedTree() throws {
        let tree = try JSONSerialization.jsonObject(with: segfaultJSON)
        let wrapped = try JSONSerialization.data(withJSONObject: ["callStackTree": tree])
        let report = MetricKitCrashReport(
            callStackTreeJSON: wrapped,
            exceptionType: 1,
            exceptionCode: 1,
            signal: 11,
            terminationReason: nil,
            build: nil
        )
        #expect(report.frames == segfault().frames)
        #expect(report.culprit?.binaryName == "PVCoreBridgeRetro")
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
        #expect(report.parseError?.hasPrefix("JSON unreadable") == true)
        #expect(report.fingerprint.last == "unparsed-frames")
        #expect(report.sentryTags["crash.frames"] == "unparsed")
        #expect(report.sentryTags["crash.build"] == nil)
    }

    /// MetricKit's nesting for a `depth`-frame stack, built as text: Swift
    /// dictionaries this deep overflow the stack when serialized or freed.
    private func nestedStackJSON(depth: Int) -> Data {
        var frames = ""
        for level in 0..<depth {
            frames += "{\"binaryName\":\"PVFrame\",\"offsetIntoBinaryTextSegment\":\(level)"
            frames += level < depth - 1 ? ",\"subFrames\":[" : "}"
        }
        frames += String(repeating: "]}", count: depth - 1)
        return Data("{\"callStacks\":[{\"threadAttributed\":true,\"callStackRootFrames\":[\(frames)]}]}".utf8)
    }

    private func report(callStackTreeJSON json: Data) -> MetricKitCrashReport {
        MetricKitCrashReport(
            callStackTreeJSON: json,
            exceptionType: 1,
            exceptionCode: nil,
            signal: 11,
            terminationReason: nil,
            build: nil
        )
    }

    @Test("A deep stack flattens in caller order")
    func flattensDeepStack() {
        let depth = 200
        let report = report(callStackTreeJSON: nestedStackJSON(depth: depth))
        #expect(report.parseError == nil)
        #expect(report.frames.map(\.offset) == (0..<UInt64(depth)).map { $0 })
    }

    /// `JSONSerialization` stops at 512 levels, about 250 frames: a
    /// stack-overflow crash must come out tagged, not as a frameless crash.
    @Test("A stack too deep for JSONSerialization is reported as unparsed")
    func reportsTooDeepStack() {
        let report = report(callStackTreeJSON: nestedStackJSON(depth: 2_000))
        #expect(report.frames.isEmpty)
        #expect(report.parseError?.hasPrefix("JSON unreadable") == true)
        #expect(report.sentryTags["crash.frames"] == "unparsed")
        #expect(report.fingerprint.last == "unparsed-frames")
    }

    @Test("A payload without call stacks says so")
    func reportsMissingCallStacks() {
        let report = MetricKitCrashReport(
            callStackTreeJSON: Data("{}".utf8),
            exceptionType: nil,
            exceptionCode: nil,
            signal: nil,
            terminationReason: nil,
            build: nil
        )
        #expect(report.parseError == "no callStacks")
        #expect(report.frames.isEmpty)
    }
}
