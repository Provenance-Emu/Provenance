//
//  CoreOptions.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 4/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

public protocol CoreOptional : class {
	static var options : [CoreOption] {get}
}

extension CoreOptional where Self:PVEmulatorCore {
	public static func valueForOption<T>(_ type: T.Type, _ option : String) -> T? {
		let className = NSStringFromClass(Self.self)
		let key = "\(className).option"

		if let savedOption = UserDefaults.standard.value(forKey: key) as? T {
			return savedOption
		} else {
			let levels = option.split(separator: ".")

			var currentOptions : [CoreOption] = options
			var foundOption : CoreOption?
			for (i, level) in levels.enumerated() {
				if i == levels.count - 1 {
					foundOption = findOption(forKey: String(level), options: currentOptions)
				} else {
					if let nextSubOption = findOption(forKey: String(level), options: currentOptions) {
						switch nextSubOption {
						case .group(_, let subOptions):
							currentOptions = subOptions
						default:
							break
						}
					} else {
						break
					}
				}
			}
			return foundOption?.defaultValue as? T
		}
	}

	static func findOption(forKey key : String, options: [CoreOption]) -> CoreOption? {
		return options.first {
			return $0.key == key
		}
	}
}

//public protocol Rangable {
//	var defaultValue : Codable {get}
//	var min : Codable {get}
//	var max : Codable {get}
//}
//
//public struct CoreOptionRange<T:Codable> : Rangable {
//	public let defaultValue : T
//	public let min : T
//	public let max : T
//}

public struct CoreOptionRange : Codable {
	public let defaultValue : Int
	public let min : Int
	public let max : Int
}

public struct CoreOptionMultiValue : Codable {
	public let title : String
	public let description : String?

	public static func values(fromArray a : [[String]]) -> [CoreOptionMultiValue] {
		return a.flatMap {
			if $0.count == 1 {
				return CoreOptionMultiValue(title: $0[0], description: nil)
			} else if $0.count >= 2 {
				return CoreOptionMultiValue(title: $0[0], description: $0[1])
			} else {
				return nil
			}
		}
	}

	public static func values(fromArray a : [String]) -> [CoreOptionMultiValue] {
		return a.map {
			return CoreOptionMultiValue(title: $0, description: nil)
		}
	}
}

public struct CoreOptionValueDisplay : Codable {
	public let title : String
	public let description : String?

	public init(title : String, description: String? = nil) {
		self.title = title
		self.description = description
	}
}

public enum CoreOption {
	case bool(display: CoreOptionValueDisplay, defaultValue: Bool)
	case range(display: CoreOptionValueDisplay, range: CoreOptionRange, defaultValue: Int)
	case multi(display: CoreOptionValueDisplay, values: [CoreOptionMultiValue])
	case string(display: CoreOptionValueDisplay, defaultValue: String)
	case group(display: CoreOptionValueDisplay, subOptions: [CoreOption])

	public var defaultValue : Any? {
		switch self {
		case .bool(_, let defaultValue):
			return defaultValue
		case .range(_, _, let defaultValue):
			return defaultValue
		case .multi(_, let values):
			return values.first?.title
		case .string(_, let defaultValue):
			return defaultValue
		case .group:
			return nil
		}
	}

	public var key : String {
		switch self {
		case .bool(let display, _):
			return display.title
		case .range(let display, _, _):
			return display.title
		case .multi(let display, _):
			return display.title
		case .string(let display, _):
			return display.title
		case .group(let display, _):
			return display.title
		}
	}

	func subOptionForKey(_ key : String) -> CoreOption? {
		switch self {
		case .group(_, let subOptions):
			return subOptions.first { $0.key == key }
		default:
			return nil
		}
	}
}

extension CoreOption : Codable {
	public enum CodingError: Error { case decoding(String) }
	enum CodableKeys: String, CodingKey { case display, defaultValue, range, values, subOptions }

	public init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodableKeys.self)

		// All cases need display
		guard let display = try? values.decode(CoreOptionValueDisplay.self, forKey: .display) else {
			throw CodingError.decoding("Decoding Failed. No display key. \(dump(values))")
		}

		// Bool
		if let defaultValue = try? values.decode(Bool.self, forKey: .defaultValue) {
			self = .bool(display: display, defaultValue: defaultValue)
			return
		}

		// Range
		if let range = try? values.decode(CoreOptionRange.self, forKey: .range), let defaultValue = try? values.decode(Int.self, forKey: .defaultValue) {
			self = .range(display: display, range: range, defaultValue: defaultValue)
			return
		}

		// multi
		if let values = try? values.decode([CoreOptionMultiValue].self, forKey: .values) {
			self = .multi(display: display, values: values)
			return
		}

		// string
		if let defaultValue = try? values.decode(String.self, forKey: .defaultValue) {
			self = .string(display: display, defaultValue: defaultValue)
			return
		}

		// group
		if let subOptions = try? values.decode([CoreOption].self, forKey: CodableKeys.subOptions) {
			self = .group(display: display, subOptions: subOptions)
			return
		}

		throw CodingError.decoding("Decoding Failed. \(dump(values))")
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodableKeys.self)

		switch self {
		case let .bool(display, defaultValue):
			try container.encode(display, forKey: .display)
			try container.encode(defaultValue, forKey: .defaultValue)
		case let .range(display, range, defaultValue):
			try container.encode(display, forKey: .display)
			try container.encode(range, forKey: .range)
			try container.encode(defaultValue, forKey: .defaultValue)
		case let .multi(display, values):
			try container.encode(display, forKey: .display)
			try container.encode(values, forKey: .values)
		case let .string(display, defaultValue):
			try container.encode(display, forKey: .display)
			try container.encode(defaultValue, forKey: .defaultValue)
		case let .group(display, subOptions):
			try container.encode(display, forKey: .display)
			try container.encode(subOptions, forKey: .subOptions)
		}
	}
}

public typealias OptionAvailable = (()->(available: Bool, reasonNotAvailable: String?))

extension CoreOptionMultiValue {
	init(title : String, description: String) {
		self.title = title
		self.description = description
	}
}

//public protocol CoreOptionP {
//	var defaultValue : ValueType {get}
//	var title : String {get}
//	var description : String {get}
//
//	var currentValue : ValueType {get}
//}

//public struct CoreOptionValue<T:Codable> {
//	let description : String
//	let value : T
//}

//public struct CoreOptionMultiple {
//	let title : String
//	let description : String
//	let values : [CoreOptionMultiValue]
//	let defaultValue : [CoreOptionMultiValue]
//}
//
//public struct CoreOption<T:Codable> {
//	typealias ValueType = T
//
//	let defaultValue : T
//	let title : String
//	let description : String
//
//
////	var currentValue : T {
////		let
////	}
//}
