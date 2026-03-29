//
//  ArchiveExtractor.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/19/24.
//
//  Thin compatibility layer that delegates to PVArchiving backends.

import Foundation
import PVLogging
import PVFileSystem
@_exported import PVSupport
@_exported import PVArchiving
import Combine

// MARK: - Backward Compatibility Typealiases

/// Maps the old PVLibrary `ArchiveType` to `PVArchiving.ArchiveFormat`.
public typealias ArchiveType = ArchiveFormat

/// Re-export SevenZipEngine so callers that referenced the old enum still compile.
public typealias SevenZipBackend = SevenZipEngine

/// Global backend selector for 7z extraction (backward compat).
public var sevenZipExtractionBackend: SevenZipEngine = .plzmaSDK

// MARK: - Extractor Protocol (internal, backward compat)

protocol ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error>
}

// MARK: - PVArchiving-backed Extractors

/// Wraps any `ArchiveExtractorBackend` to conform to the internal `ArchiveExtractor` protocol.
private struct BackendExtractor: ArchiveExtractor {
    let backend: any ArchiveExtractorBackend

    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        backend.extract(at: path, to: destination, progress: progress)
    }
}

/// ZIP extractor using PVArchiving's ZipBackend.
class ZipExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        ZipBackend().extract(at: path, to: destination, progress: progress)
    }
}

/// 7z extractor using PVArchiving's SevenZipBackend, respecting the global backend preference.
class SevenZipExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        PVArchiving.SevenZipBackend(engine: sevenZipExtractionBackend).extract(at: path, to: destination, progress: progress)
    }
}

class BZip2Extractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        BZip2Backend().extract(at: path, to: destination, progress: progress)
    }
}

class GZipExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        GZipBackend().extract(at: path, to: destination, progress: progress)
    }
}

class TarExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        TarBackend().extract(at: path, to: destination, progress: progress)
    }
}

class XZExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        XZBackend().extract(at: path, to: destination, progress: progress)
    }
}

class LzhExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        LzhBackend().extract(at: path, to: destination, progress: progress)
    }
}

class RarExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        RarBackend().extract(at: path, to: destination, progress: progress)
    }
}
