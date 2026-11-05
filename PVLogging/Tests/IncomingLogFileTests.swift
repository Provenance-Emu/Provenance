//
//  IncomingLogFileTests.swift
//  PVLoggingTests
//
//  Covers the routing decision for files handed to the app: is it a log export
//  for the log viewer, or something for the ROM importer (#3612)?
//
import Testing
import Foundation
@testable import PVLogging

@Suite("IncomingLogFile inspection")
struct IncomingLogFileInspectionTests {

    @Test("A .log needs no inspection", arguments: ["log", "LOG", "Log"])
    func logExtensionNeedsNothing(ext: String) {
        #expect(IncomingLogFile.inspection(for: ext) == .none)
    }

    @Test("A .zip needs its entry list", arguments: ["zip", "ZIP"])
    func zipNeedsEntries(ext: String) {
        #expect(IncomingLogFile.inspection(for: ext) == .archiveEntries)
    }

    @Test("A .txt needs its first bytes", arguments: ["txt", "TXT"])
    func txtNeedsPrefix(ext: String) {
        #expect(IncomingLogFile.inspection(for: ext) == .textPrefix)
    }

    @Test("ROM, skin and unknown extensions need nothing and are never logs",
          arguments: ["nes", "sfc", "7z", "deltaskin", "", "cue"])
    func otherExtensionsNeedNothing(ext: String) {
        #expect(IncomingLogFile.inspection(for: ext) == .none)
        #expect(IncomingLogFile.classify(fileExtension: ext) == .other)
    }
}

@Suite("IncomingLogFile classification")
struct IncomingLogFileClassifyTests {

    @Test("Any .log is a plain log regardless of contents or case")
    func logIsAlwaysPlainLog() {
        #expect(IncomingLogFile.classify(fileExtension: "log") == .plainLog)
        #expect(IncomingLogFile.classify(fileExtension: "LOG") == .plainLog)
        // Extra inputs are ignored for an unambiguous extension.
        #expect(IncomingLogFile.classify(fileExtension: "log", archiveEntryPaths: [], textPrefix: "garbage") == .plainLog)
    }

    @Test("An exported ZIP bundle is recognised by its marker files")
    func exportedZipIsBundle() {
        let nested = ["pv_log_export_2026-11-03_10-00-00/device_info.txt",
                      "pv_log_export_2026-11-03_10-00-00/app_logs.txt"]
        #expect(IncomingLogFile.classify(fileExtension: "zip", archiveEntryPaths: nested) == .logBundle)

        let flat = ["device_info.txt"]
        #expect(IncomingLogFile.classify(fileExtension: "zip", archiveEntryPaths: flat) == .logBundle)

        let appLogsOnly = ["export/app_logs.txt"]
        #expect(IncomingLogFile.classify(fileExtension: "zip", archiveEntryPaths: appLogsOnly) == .logBundle)
    }

    @Test("A RetroArch-only export (app logs and device info switched off) is still a bundle")
    func retroArchOnlyExportIsBundle() {
        let paths = ["pv_log_export/retroarch_logs/", "pv_log_export/retroarch_logs/retroarch.log"]
        #expect(IncomingLogFile.classify(fileExtension: "zip", archiveEntryPaths: paths) == .logBundle)
    }

    @Test("Marker names match case-insensitively")
    func markerNamesAreCaseInsensitive() {
        #expect(IncomingLogFile.isLogBundle(entryPaths: ["Export/DEVICE_INFO.TXT"]))
        #expect(IncomingLogFile.isLogBundle(entryPaths: ["Export/RetroArch_Logs/x.log"]))
    }

    @Test("A ROM archive is not a log bundle")
    func romZipIsOther() {
        let paths = ["Game (USA).nes", "Game (USA).sfc", "readme.txt", "logo.png", "manifest.json"]
        #expect(IncomingLogFile.classify(fileExtension: "zip", archiveEntryPaths: paths) == .other)
    }

    @Test("Look-alike names in a ROM archive do not count")
    func lookAlikesDoNotMatch() {
        // Directory entries, resource-fork copies and names that merely contain the marker.
        let paths = ["set/device_info.txt/",
                     "__MACOSX/._device_info.txt",
                     "set/my_device_info.txt",
                     "set/app_logs.txt.bak"]
        #expect(!IncomingLogFile.isLogBundle(entryPaths: paths))
    }

    @Test("An unreadable or empty archive is not a log bundle")
    func unreadableZipIsOther() {
        #expect(IncomingLogFile.classify(fileExtension: "zip", archiveEntryPaths: nil) == .other)
        #expect(IncomingLogFile.classify(fileExtension: "zip", archiveEntryPaths: []) == .other)
    }

    @Test("A .txt that starts with the export header is a plain log")
    func exportedTextIsPlainLog() {
        let header = IncomingLogFile.exportHeader + "\nDate: today\n"
        #expect(IncomingLogFile.classify(fileExtension: "txt", textPrefix: header) == .plainLog)

        let logsOnly = IncomingLogFile.appLogsHeader + "\n[12:00:00.000] [INFO] hi"
        #expect(IncomingLogFile.classify(fileExtension: "txt", textPrefix: logsOnly) == .plainLog)
    }

    @Test("A BOM or leading blank lines before the header are tolerated")
    func headerAfterBOMOrWhitespace() {
        #expect(IncomingLogFile.isExportedLogText("\u{FEFF}" + IncomingLogFile.exportHeader))
        #expect(IncomingLogFile.isExportedLogText("\n\n  " + IncomingLogFile.exportHeader))
        #expect(IncomingLogFile.isExportedLogText("\r\n" + IncomingLogFile.appLogsHeader))
    }

    @Test("Other text files are not logs")
    func otherTextIsOther() {
        #expect(IncomingLogFile.classify(fileExtension: "txt", textPrefix: "video_driver = \"vulkan\"") == .other)
        #expect(IncomingLogFile.classify(fileExtension: "txt", textPrefix: "README\n" + IncomingLogFile.exportHeader) == .other)
        #expect(IncomingLogFile.classify(fileExtension: "txt", textPrefix: "") == .other)
        #expect(IncomingLogFile.classify(fileExtension: "txt", textPrefix: nil) == .other)
    }

    @Test("Text markers alone never promote a non-text extension")
    func markersDoNotPromoteOtherExtensions() {
        #expect(IncomingLogFile.classify(fileExtension: "nes", textPrefix: IncomingLogFile.exportHeader) == .other)
        #expect(IncomingLogFile.classify(fileExtension: "7z", archiveEntryPaths: ["device_info.txt"]) == .other)
    }
}
