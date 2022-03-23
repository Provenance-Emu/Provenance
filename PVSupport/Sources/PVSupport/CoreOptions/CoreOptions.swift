//
//  CoreOptions.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 4/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

public enum CoreOption {
    case bool(_ display: CoreOptionValueDisplay, defaultValue: Bool = false)
    case range(_ display: CoreOptionValueDisplay, range: CoreOptionRange<Int>, defaultValue: Int)
	case rangef(_ display: CoreOptionValueDisplay, range: CoreOptionRange<Float>, defaultValue: Float)
    case multi(_ display: CoreOptionValueDisplay, values: [CoreOptionMultiValue])
    case enumeration(_ display: CoreOptionValueDisplay, values: [CoreOptionEnumValue], defaultValue: Int = 0)
    case string(_ display: CoreOptionValueDisplay, defaultValue: String = "")
    case group(_ display: CoreOptionValueDisplay, subOptions: [CoreOption])

    public var defaultValue: OptionValueRepresentable? {
        switch self {
        case let .bool(_, defaultValue):
            return defaultValue
        case let .range(_, _, defaultValue):
            return defaultValue
		case let .rangef(_, _, defaultValue):
			return defaultValue
        case let .multi(_, values):
            return values.filter { $0.isDefault }.map{ $0.title }
//            return values.first { $0.isDefault }?.title
		case let .enumeration(_, _, defaultValue):
			return defaultValue
        case let .string(_, defaultValue):
            return defaultValue
        case .group:
            return nil
        }
    }

    public var key: String {
        switch self {
        case .bool(let display, _):
            return display.title
        case .range(let display, _, _):
            return display.title
		case .rangef(let display, _, _):
			return display.title
        case .multi(let display, _):
            return display.title
        case .string(let display, _):
            return display.title
        case .group(let display, _):
            return display.title
		case .enumeration(let display, _, _):
			return display.title
		}
    }

    func subOptionForKey(_ key: String) -> CoreOption? {
        switch self {
        case let .group(_, subOptions):
            return subOptions.first { $0.key == key }
        default:
            return nil
        }
    }
}

extension CoreOption: Equatable {
    // MARK: - Equatable

    /// Returns true iff `lhs` and `rhs` have equal titles, detail texts, selection states, and icons.
//    public static func == (lhs: CoreOption, rhs: CoreOption) -> Bool {
//      return
//        lhs.text == rhs.text &&
//        lhs.detailText == rhs.detailText &&
//        lhs.isSelected == rhs.isSelected &&
//        lhs.icon == rhs.icon
//    }
}

extension CoreOption: Codable {
    public enum CodingError: Error { case decoding(String) }
    enum CodableKeys: String, CodingKey { case display, defaultValue, range, rangef, values, subOptions }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodableKeys.self)

        // All cases need display
        guard let display = try? values.decode(CoreOptionValueDisplay.self, forKey: .display) else {
            throw CodingError.decoding("Decoding Failed. No display key. \(dump(values))")
        }

        // Bool
        if let defaultValue = try? values.decode(Bool.self, forKey: .defaultValue) {
            self = .bool(display, defaultValue: defaultValue)
            return
        }

        // Range
        if let range = try? values.decode(CoreOptionRange<Int>.self, forKey: .range), let defaultValue = try? values.decode(Int.self, forKey: .defaultValue) {
            self = .range(display, range: range, defaultValue: defaultValue)
            return
        }

		// Rangef
		if let rangef = try? values.decode(CoreOptionRange<Float>.self, forKey: .rangef), let defaultValue = try? values.decode(Float.self, forKey: .defaultValue) {
			self = .rangef(display, range: rangef, defaultValue: defaultValue)
			return
		}

        // multi
        if let values = try? values.decode([CoreOptionMultiValue].self, forKey: .values) {
            self = .multi(display, values: values)
            return
        }

        // string
        if let defaultValue = try? values.decode(String.self, forKey: .defaultValue) {
            self = .string(display, defaultValue: defaultValue)
            return
        }

        // group
        if let subOptions = try? values.decode([CoreOption].self, forKey: CodableKeys.subOptions) {
            self = .group(display, subOptions: subOptions)
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
		case let .rangef(display, range, defaultValue):
			try container.encode(display, forKey: .display)
			try container.encode(range, forKey: .range)
			try container.encode(defaultValue, forKey: .defaultValue)
        case let .multi(display, values):
            try container.encode(display, forKey: .display)
            try container.encode(values, forKey: .values)
		case let .enumeration(display, values, defaultValue):
			try container.encode(display, forKey: .display)
			try container.encode(values, forKey: .values)
            try container.encode(defaultValue, forKey: .defaultValue)
        case let .string(display, defaultValue):
            try container.encode(display, forKey: .display)
            try container.encode(defaultValue, forKey: .defaultValue)
        case let .group(display, subOptions):
            try container.encode(display, forKey: .display)
            try container.encode(subOptions, forKey: .subOptions)
        }
    }
}

public typealias OptionAvailable = (() -> (available: Bool, reasonNotAvailable: String?))

// public struct CoreOptionModel : COption {
//
//    let key : String
//    let title : String
//    let description: String?
//
//    let defaultValue : ValueType
//
//    var value : ValueType {
//        return UserDefaults.standard.value(forKey: key) as? ValueType ?? defaultValue
//    }
//
//    public init<ValueType:OptionValueRepresentable>(key: String, title: String, description: String? = nil, defaultValue: ValueType) {
//        self.key = key
//        self.title = title
//        self.description = description
//        self.defaultValue = defaultValue
//    }
// }

// public protocol CoreOptionP {
//	var defaultValue : ValueType {get}
//	var title : String {get}
//	var description : String {get}
//
//	var currentValue : ValueType {get}
// }

// public struct CoreOptionValue<T:Codable> {
//	let description : String
//	let value : T
// }

// public struct CoreOptionMultiple {
//	let title : String
//	let description : String
//	let values : [CoreOptionMultiValue]
//	let defaultValue : [CoreOptionMultiValue]
// }
//
// public struct CoreOption<T:Codable> {
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
// }
