//
//  CoreOptions.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 4/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

public protocol CoreOptions: CoreOptional {
    static var options: [CoreOption] { get }
}

public extension CoreOptions {
    static func bool(forOption option: String) -> Bool {
        return storedValueForOption(Bool.self, option) ?? false
    }

    static func int(forOption option: String) -> Int {
        let value = storedValueForOption(Int.self, option)
        return value ?? 0
    }

    static func float(forOption option: String) -> Float {
        let value = storedValueForOption(Float.self, option)
        return value ?? 0
    }

    static func string(forOption option: String) -> String? {
        let value = storedValueForOption(String.self, option)
        return value
    }
}

@objc @objcMembers public class CoreOptionAccessor: NSObject {
    public typealias OptionSetter = (AnyObject) -> Void
    public typealias OptionGetter = () -> AnyObject?

    @objc public let getOption: OptionGetter
    @objc public let setOption: OptionSetter

    public init(getOption: @escaping OptionGetter, setOption: @escaping OptionSetter) {
        self.getOption = getOption
        self.setOption = setOption
    }
}

public enum CoreOption: Sendable {
    case bool(_ display: CoreOptionValueDisplay, defaultValue: Bool = false, valueHandler:  (@Sendable (OptionValueRepresentable) -> Void)? = nil)
    case range(_ display: CoreOptionValueDisplay, range: CoreOptionRange<Int>, defaultValue: Int, valueHandler: (@Sendable (OptionValueRepresentable) -> Void)? = nil)
	case rangef(_ display: CoreOptionValueDisplay, range: CoreOptionRange<Float>, defaultValue: Float, valueHandler: (@Sendable (OptionValueRepresentable) -> Void)? = nil)
    case multi(_ display: CoreOptionValueDisplay, values: [CoreOptionMultiValue], valueHandler: (@Sendable (OptionValueRepresentable) -> Void)? = nil)
    case enumeration(_ display: CoreOptionValueDisplay, values: [CoreOptionEnumValue], defaultValue: Int = 0, valueHandler: (@Sendable (OptionValueRepresentable) -> Void)? = nil)
    case string(_ display: CoreOptionValueDisplay, defaultValue: String = "", valueHandler: (@Sendable (OptionValueRepresentable) -> Void)? = nil)
    case group(_ display: CoreOptionValueDisplay, subOptions: [CoreOption])

    public var defaultValue: OptionValueRepresentable? {
        switch self {
        case let .bool(_, defaultValue, _):
            return defaultValue
        case let .range(_, _, defaultValue, _):
            return defaultValue
		case let .rangef(_, _, defaultValue, _):
			return defaultValue
        case let .multi(_, values, _):
            return values.filter { $0.isDefault }.map { $0.title }
//            return values.first { $0.isDefault }?.title
		case let .enumeration(_, _, defaultValue, _):
			return defaultValue
        case let .string(_, defaultValue, _):
            return defaultValue
        case .group:
            return nil
        }
    }

    public var key: String {
        switch self {
        case .bool(let display, _, _):
            return display.title
        case .range(let display, _, _, _):
            return display.title
		case .rangef(let display, _, _, _):
			return display.title
        case .multi(let display, _, _):
            return display.title
        case .string(let display, _, _):
            return display.title
        case .group(let display, _):
            return display.title
		case .enumeration(let display, _, _, _):
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

    public var valueHandler: ((OptionValueRepresentable) -> Void)? {
        get {
            switch self {
            case .bool(_, _, let handler),
                 .range(_, _, _, let handler),
                 .rangef(_, _, _, let handler),
                 .multi(_, _, let handler),
                 .enumeration(_, _, _, let handler),
                 .string(_, _, let handler):
                return handler
            case .group:
                return nil
            }
        }
        set {
            // This would need to be implemented if we want to set the handler after creation
            // For now, we'll set it during initialization
        }
    }
}

extension CoreOption: Equatable {
    // MARK: - Equatable

    /// Returns true if two CoreOptions are equivalent
    public static func == (lhs: CoreOption, rhs: CoreOption) -> Bool {
        // First check if they're the same type and have the same key
        switch (lhs, rhs) {
        case (.bool(let lhsDisplay, let lhsDefault, _), .bool(let rhsDisplay, let rhsDefault, _)):
            return lhsDisplay.title == rhsDisplay.title && lhsDefault == rhsDefault

        case (.range(let lhsDisplay, let lhsRange, let lhsDefault, _),
              .range(let rhsDisplay, let rhsRange, let rhsDefault, _)):
            return lhsDisplay.title == rhsDisplay.title &&
                   lhsRange.min == rhsRange.min &&
                   lhsRange.max == rhsRange.max &&
                   lhsDefault == rhsDefault

        case (.rangef(let lhsDisplay, let lhsRange, let lhsDefault, _),
              .rangef(let rhsDisplay, let rhsRange, let rhsDefault, _)):
            return lhsDisplay.title == rhsDisplay.title &&
                   lhsRange.min == rhsRange.min &&
                   lhsRange.max == rhsRange.max &&
                   lhsDefault == rhsDefault

        case (.multi(let lhsDisplay, let lhsValues, _), .multi(let rhsDisplay, let rhsValues, _)):
            return lhsDisplay.title == rhsDisplay.title && lhsValues == rhsValues

        case (.enumeration(let lhsDisplay, let lhsValues, let lhsDefault, _),
              .enumeration(let rhsDisplay, let rhsValues, let rhsDefault, _)):
            return lhsDisplay.title == rhsDisplay.title &&
                   lhsValues == rhsValues &&
                   lhsDefault == rhsDefault

        case (.string(let lhsDisplay, let lhsDefault, _), .string(let rhsDisplay, let rhsDefault, _)):
            return lhsDisplay.title == rhsDisplay.title && lhsDefault == rhsDefault

        case (.group(let lhsDisplay, let lhsSubOptions), .group(let rhsDisplay, let rhsSubOptions)):
            // For groups, compare title and recursively compare suboptions
            guard lhsDisplay.title == rhsDisplay.title else { return false }

            // If suboption counts differ, they're not equal
            guard lhsSubOptions.count == rhsSubOptions.count else { return false }

            // Compare each suboption
            for i in 0..<lhsSubOptions.count {
                if lhsSubOptions[i] != rhsSubOptions[i] {
                    return false
                }
            }

            return true

        default:
            // Different types are never equal
            return false
        }
    }
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
        case let .bool(display, defaultValue, _):
            try container.encode(display, forKey: .display)
            try container.encode(defaultValue, forKey: .defaultValue)
        case let .range(display, range, defaultValue, _):
            try container.encode(display, forKey: .display)
            try container.encode(range, forKey: .range)
            try container.encode(defaultValue, forKey: .defaultValue)
		case let .rangef(display, range, defaultValue, _):
			try container.encode(display, forKey: .display)
			try container.encode(range, forKey: .range)
			try container.encode(defaultValue, forKey: .defaultValue)
        case let .multi(display, values, _):
            try container.encode(display, forKey: .display)
            try container.encode(values, forKey: .values)
		case let .enumeration(display, values, defaultValue, _):
			try container.encode(display, forKey: .display)
			try container.encode(values, forKey: .values)
            try container.encode(defaultValue, forKey: .defaultValue)
        case let .string(display, defaultValue, _):
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
