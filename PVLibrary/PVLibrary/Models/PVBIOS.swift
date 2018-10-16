//
//  PVBIOS.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

public protocol BIOSProtocol {
	var expectedMD5 : String {get}
	var expectedFilename : String {get}
	var expectedSize : Int {get}

	var optional : Bool {get}
	var descriptionText : String {get}
	var status : BIOSStatus {get}
}

@objcMembers
public final class PVBIOS: Object, PVFiled, BIOSProtocol {
    dynamic public var system: PVSystem!
    dynamic public var descriptionText: String = ""
    dynamic public var optional: Bool = false

    dynamic public var expectedMD5: String = ""
    dynamic public var expectedSize: Int = 0
    dynamic public var expectedFilename: String = ""

    dynamic public var file: PVFile?

    public convenience init(withSystem system: PVSystem, descriptionText: String, optional: Bool = false, expectedMD5: String, expectedSize: Int, expectedFilename: String) {
        self.init()
        self.system = system
        self.descriptionText = descriptionText
        self.optional = optional
        self.expectedMD5 = expectedMD5
        self.expectedSize = expectedSize
        self.expectedFilename = expectedFilename
    }

    override public static func primaryKey() -> String? {
        return "expectedFilename"
    }
}

public struct BIOS : Codable, BIOSProtocol {
	public let descriptionText: String
	public let optional : Bool

	public let expectedMD5 : String
	public let expectedSize : Int
	public let expectedFilename : String

	public let status : BIOSStatus
}

public extension BIOS {
	public init(with bios : PVBIOS) {
		descriptionText = bios.descriptionText
		optional = bios.optional
		expectedMD5 = bios.expectedMD5
		expectedSize = bios.expectedSize
		expectedFilename = bios.expectedFilename
		status = bios.status
	}
}

public extension PVBIOS {
	var expectedPath: URL {
		return system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false)
	}
}

public extension PVBIOS {
	public var status : BIOSStatus {
		return BIOSStatus(withBios: self)
	}
}

public struct BIOSStatus : Codable {
	public enum Mismatch : Codable {
		public enum CodingError: Error { case decoding(String) }

		enum CodableKeys: String, CodingKey { case md5, size, filename, expectedMD5, actualMD5, expectedSize, actualSize, expectedFilename, actualFilename}

		public init(from decoder: Decoder) throws {
			let values = try decoder.container(keyedBy: Mismatch.CodableKeys.self)

			// md5
			if let expected = try? values.decode(String.self, forKey: .expectedMD5), let actual = try? values.decode(String.self, forKey: .actualMD5)  {
				self = .md5(expected: expected, actual: actual)
				return
			}

			// size
			if let expected = try? values.decode(UInt.self, forKey: .expectedSize), let actual = try? values.decode(UInt.self, forKey: .actualSize)  {
				self = .size(expected: expected, actual: actual)
				return
			}

			// filename
			if let expected = try? values.decode(String.self, forKey: .expectedFilename), let actual = try? values.decode(String.self, forKey: .actualFilename)  {
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
	}

	public enum State : Codable {
		public enum CodingError: Error { case uknownRawValue(Int) }

		case missing
		case mismatch([Mismatch])
		case match

		enum CodableKeys: String, CodingKey { case rawValue, mismatches}

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
					throw CodingError.uknownRawValue(rawValue)
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
				break
			case .mismatch(let mismatches):
				try container.encode(1, forKey: .rawValue)
				try container.encode(mismatches, forKey: .mismatches)
			case .match:
				try container.encode(2, forKey: .rawValue)
			}
		}
	}

	public let available : Bool
	public let required : Bool
	public let state : State
}

extension BIOSStatus {
	init(withBios bios : PVBIOS) {

		available = !(bios.file?.missing ?? true)
		if available {
			let md5Match = bios.file?.md5 == bios.expectedMD5
			let sizeMatch = bios.file?.size == UInt64(bios.expectedSize)
			let filenameMatch = bios.file?.fileName == bios.expectedFilename

			var misses = [Mismatch]()
			if !md5Match {
				misses.append(.md5(expected: bios.expectedMD5, actual: bios.file?.md5 ?? "0"))
			}
			if !sizeMatch {
				misses.append(.size(expected: UInt(bios.expectedSize), actual: UInt(bios.file?.size ?? 0)))
			}
			if !filenameMatch {
				misses.append(.filename(expected: bios.expectedFilename, actual: bios.file?.fileName ?? "Nil"))
			}

			state = misses.isEmpty ? .match : .mismatch(misses)
		} else {
			state = .missing
		}
		required = !bios.optional
	}
}

public class BiosFile : PVFile {
    
}

