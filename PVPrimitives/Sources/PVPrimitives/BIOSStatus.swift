//
//  BIOSStatus.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

public struct BIOSStatus: Codable, Sendable, Equatable {
    public enum Mismatch: Codable, Sendable, CustomStringConvertible, Equatable {
        public enum CodingError: Error { case decoding(String) }

        enum CodableKeys: String, CodingKey { case md5, size, filename, expectedMD5, actualMD5, expectedSize, actualSize, expectedFilename, actualFilename }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: Mismatch.CodableKeys.self)

            // md5
            if let expected = try? values.decode(String.self, forKey: .expectedMD5), let actual = try? values.decode(String.self, forKey: .actualMD5) {
                self = .md5(expected: expected, actual: actual)
                return
            }

            // size
            if let expected = try? values.decode(UInt.self, forKey: .expectedSize), let actual = try? values.decode(UInt.self, forKey: .actualSize) {
                self = .size(expected: expected, actual: actual)
                return
            }

            // filename
            if let expected = try? values.decode(String.self, forKey: .expectedFilename), let actual = try? values.decode(String.self, forKey: .actualFilename) {
                self = .filename(expected: expected, actual: actual)
                return
            }

            throw CodingError.decoding("No known case")
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodableKeys.self)

            switch self {
            case let .md5(expected, actual):
                try container.encode(expected, forKey: .expectedMD5)
                try container.encode(actual, forKey: .actualMD5)
            case let .size(expected, actual):
                try container.encode(expected, forKey: .expectedSize)
                try container.encode(actual, forKey: .actualSize)
            case let .filename(expected, actual):
                try container.encode(expected, forKey: .expectedFilename)
                try container.encode(actual, forKey: .actualFilename)
            }
        }

        case md5(expected: String, actual: String)
        case size(expected: UInt, actual: UInt)
        case filename(expected: String, actual: String)
        
        public var description: String {
            switch self {
            case let .md5(expected, actual):
                return "MD5 mismatch: expected \(expected), actual \(actual)"
            case let .size(expected, actual):
                return "Size mismatch: expected \(expected), actual \(actual)"
            case let .filename(expected, actual):
                return "Filename mismatch: expected \(expected), actual \(actual)"
            }
        }
    }

    public enum State: Codable, Sendable, Equatable {
        public enum CodingError: Error { case unknownRawValue(Int) }

        case missing
        case mismatch([Mismatch])
        case match

        enum CodableKeys: String, CodingKey { case rawValue, mismatches }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: State.CodableKeys.self)

            if let rawValue = try? values.decode(Int.self, forKey: .rawValue) {
                switch rawValue {
                case 0:
                    self = .missing
                    return
                case 1:
                    if let mismatches = try? values.decode([Mismatch].self, forKey: .mismatches) {
                        self = .mismatch(mismatches)
                    } else {
                        fatalError("Mismatch missing mismatches value coding")
                    }
                    return
                case 2:
                    self = .match
                    return
                default:
                    throw CodingError.unknownRawValue(rawValue)
                }
            } else {
                fatalError("No known decode")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: State.CodableKeys.self)

            switch self {
            case .missing:
                try container.encode(0, forKey: .rawValue)
            case let .mismatch(mismatches):
                try container.encode(1, forKey: .rawValue)
                try container.encode(mismatches, forKey: .mismatches)
            case .match:
                try container.encode(2, forKey: .rawValue)
            }
        }

        public init(expectations: BIOSExpectationsInfoProvider, file: FileInfoProvider) {
            if file.online {
                let md5Match = file.md5?.uppercased() == expectations.expectedMD5.uppercased()
                let sizeMatch = file.size == UInt64(expectations.expectedSize)
                let filenameMatch = file.fileName == expectations.expectedFilename

                var misses = [Mismatch]()
                if !md5Match {
                    misses.append(.md5(expected: expectations.expectedMD5.uppercased(), actual: file.md5?.uppercased() ?? "0"))
                }
                if !sizeMatch {
                    misses.append(.size(expected: UInt(expectations.expectedSize), actual: UInt(file.size)))
                }
                if !filenameMatch {
                    misses.append(.filename(expected: expectations.expectedFilename, actual: file.fileName))
                }

                self = misses.isEmpty ? .match : .mismatch(misses)
            } else {
                self = .missing
            }
        }
    }

    public let available: Bool
    public let required: Bool
    public let state: State
}

public extension BIOSStatus {
    init<T: BIOSFileProvider>(withBios bios: T) {
        available = bios.fileInfo != nil
        if available {
            let md5Match = bios.fileInfo?.md5?.uppercased() == bios.expectedMD5.uppercased()
            let sizeMatch = bios.fileInfo?.size == UInt64(bios.expectedSize)
            let filenameMatch = bios.fileInfo?.fileName == bios.expectedFilename

            var misses = [Mismatch]()
            if !md5Match {
                misses.append(.md5(expected: bios.expectedMD5.uppercased(), actual: bios.fileInfo?.md5?.uppercased() ?? "0"))
            }
            if !sizeMatch {
                misses.append(.size(expected: UInt(bios.expectedSize), actual: UInt(bios.fileInfo?.size ?? 0)))
            }
            if !filenameMatch {
                misses.append(.filename(expected: bios.expectedFilename, actual: bios.fileInfo?.fileName ?? "Nil"))
            }

            state = misses.isEmpty ? .match : .mismatch(misses)
        } else {
            state = .missing
        }
        required = !bios.optional
    }
}
