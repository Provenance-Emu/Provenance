//
//  CoreOptionValue.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public enum CoreOptionValue {
    case bool(Bool)
    case string(String)
    case int(Int)
    case float(Float)
    case notFound

    public var asBool: Bool {
        switch self {
        case .bool(let value): return value
        case .string(let value): return Bool(value) ?? false
        case .int(let value): return value >= 1 ? true : false
        case .float(let value): return value >= 1 ? true : false
        case .notFound: return false
        }
    }

    public var asString: String {
        switch self {
        case .bool(let value): return value ? "true" : "false"
        case .string(let value): return value
        case .int(let value): return "\(value)"
        case .float(let value): return "\(value)"
        case .notFound: return "not found"
        }
    }

    public var asInt: Int? {
        switch self {
        case .bool(let value): return value ? 1 : 0
        case .string(let value): return Int(value)
        case .int(let value): return value
        case .float(let value): return Int(value)
        case .notFound: return nil
        }
    }

    public var asFloat: Float? {
        switch self {
        case .bool(let value): return value ? 1 : 0
        case .string(let value): return Float(value)
        case .int(let value): return Float(value)
        case .float(let value): return value
        case .notFound: return nil
        }
    }
}

extension CoreOptionValue: Codable {
    enum CodableKeys: String, CodingKey { case value, type }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodableKeys.self)
        switch self {
        case let .bool(value):
            try container.encode(value, forKey: .value)
            try container.encode("bool", forKey: .type)
        case let .string(value):
            try container.encode(value, forKey: .value)
            try container.encode("string", forKey: .type)
        case let .int(value):
            try container.encode(value, forKey: .value)
            try container.encode("int", forKey: .type)
        case let .float(value):
            try container.encode(value, forKey: .value)
            try container.encode("float", forKey: .type)
        case .notFound:
            break
        }
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodableKeys.self)
        let type = try values.decode(String.self, forKey: .type)

        switch type {
        case "bool":
            let value = try values.decode(Bool.self, forKey: .value)
            self = .bool(value)
            return
        case "string":
            let value = try values.decode(String.self, forKey: .value)
            self = .string(value)
            return
        case "float":
            let value = try values.decode(Float.self, forKey: .value)
            self = .float(value)
            return
        case "int":
            let value = try values.decode(Int.self, forKey: .value)
            self = .int(value)
            return
        default:
            self = .notFound
            return
        }
    }
}
