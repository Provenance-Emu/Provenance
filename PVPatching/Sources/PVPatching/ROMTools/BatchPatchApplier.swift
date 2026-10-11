//
//  BatchPatchApplier.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// One patch/ROM pair prepared for batch apply.
public struct BatchPatchJob: Sendable, Identifiable, Equatable {
    public var id: String { patchURL.path }
    public var patchURL: URL
    public var romURL: URL
    public var romTitle: String
    public var confidence: PatchMatchConfidence
    public var crcValidation: PatchCRCValidation

    public init(
        patchURL: URL,
        romURL: URL,
        romTitle: String,
        confidence: PatchMatchConfidence,
        crcValidation: PatchCRCValidation
    ) {
        self.patchURL = patchURL
        self.romURL = romURL
        self.romTitle = romTitle
        self.confidence = confidence
        self.crcValidation = crcValidation
    }
}

public struct BatchPatchResult: Sendable, Equatable {
    public var patchURL: URL
    public var outputURL: URL?
    public var success: Bool
    public var message: String

    public init(patchURL: URL, outputURL: URL? = nil, success: Bool, message: String) {
        self.patchURL = patchURL
        self.outputURL = outputURL
        self.success = success
        self.message = message
    }
}

/// Matches a folder of patches to candidate ROMs and applies them.
public actor BatchPatchApplier {
    public struct ROMCandidate: Sendable, Equatable {
        public var id: String
        public var title: String
        public var filename: String
        public var fileURL: URL
        public var crc32: UInt32?

        public init(id: String, title: String, filename: String, fileURL: URL, crc32: UInt32? = nil) {
            self.id = id
            self.title = title
            self.filename = filename
            self.fileURL = fileURL
            self.crc32 = crc32
        }
    }

    private let inspector = PatchInspector()
    private let applier: PatchApplier
    private let patchExtensions: Set<String> = [
        "ips", "ips32", "bps", "ups", "ppf", "xdelta", "vcdiff"
    ]

    public init(applier: PatchApplier = PatchApplier()) {
        self.applier = applier
    }

    /// Enumerate patch files under `directory` (non-recursive by default).
    public func patchFiles(in directory: URL, recursive: Bool = false) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: recursive ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }
        var urls: [URL] = []
        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            if patchExtensions.contains(ext) {
                urls.append(url)
            }
        }
        return urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Build apply jobs by matching each patch to the best unambiguous ROM candidate.
    public func plan(
        patchURLs: [URL],
        roms: [ROMCandidate],
        minimumConfidence: PatchMatchConfidence = .medium
    ) throws -> [BatchPatchJob] {
        var jobs: [BatchPatchJob] = []
        let candidates: [PatchMatchCandidate] = roms.map {
            PatchMatchCandidate(
                id: $0.id,
                title: $0.title,
                md5: $0.id,
                crc32: $0.crc32,
                filename: $0.filename,
                confidence: .none,
                score: 0
            )
        }

        for patchURL in patchURLs {
            let inspection = try inspector.inspect(patchURL: patchURL)
            let ranked = inspector.rank(
                candidates: candidates,
                inspection: inspection,
                patchFilename: patchURL.lastPathComponent
            )
            guard let best = inspector.unambiguousMatch(from: ranked),
                  best.confidence >= minimumConfidence,
                  let rom = roms.first(where: { $0.id == best.id }) else {
                continue
            }
            let validation = PatchCRCValidator.validate(romCRC: rom.crc32, inspection: inspection)
            jobs.append(
                BatchPatchJob(
                    patchURL: patchURL,
                    romURL: rom.fileURL,
                    romTitle: rom.title,
                    confidence: best.confidence,
                    crcValidation: validation
                )
            )
        }
        return jobs
    }

    /// Apply planned jobs. Skips CRC mismatches unless `allowCRCMismatch` is true.
    public func apply(
        jobs: [BatchPatchJob],
        outputDirectory: URL,
        allowCRCMismatch: Bool = false,
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) async -> [BatchPatchResult] {
        var results: [BatchPatchResult] = []
        let total = max(jobs.count, 1)
        for (index, job) in jobs.enumerated() {
            let base = Double(index) / Double(total)
            progress?(PatchProgress(
                fractionCompleted: base,
                status: "Applying \(job.patchURL.lastPathComponent)…"
            ))
            if job.crcValidation.isMismatch, !allowCRCMismatch {
                results.append(
                    BatchPatchResult(
                        patchURL: job.patchURL,
                        success: false,
                        message: job.crcValidation.userMessage
                    )
                )
                continue
            }
            do {
                let url = try await applier.exportPatchedCopy(
                    patchURL: job.patchURL,
                    romURL: job.romURL,
                    to: outputDirectory
                ) { step in
                    let overall = base + (step.fractionCompleted / Double(total))
                    progress?(PatchProgress(fractionCompleted: overall, status: step.status))
                }
                results.append(
                    BatchPatchResult(
                        patchURL: job.patchURL,
                        outputURL: url,
                        success: true,
                        message: "Wrote \(url.lastPathComponent) for \(job.romTitle)"
                    )
                )
            } catch {
                results.append(
                    BatchPatchResult(
                        patchURL: job.patchURL,
                        success: false,
                        message: error.localizedDescription
                    )
                )
            }
        }
        progress?(PatchProgress(fractionCompleted: 1.0, status: "Done"))
        return results
    }
}
