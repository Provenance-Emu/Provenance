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
    case number(NSNumber)
    case notFound

    public var asBool: Bool {
        switch self {
        case .bool(let value): return value
        case .string(let value): return Bool(value) ?? false
        case .number(let value): return value.boolValue
        case .notFound: return false
        }
    }
}

extension CoreOptionValue: Codable {
    enum CodableKeys: String, CodingKey { case value }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodableKeys.self)
        switch self {
        case let .bool(value):
            try container.encode(value, forKey: .value)
        case let .string(value):
            try container.encode(value, forKey: .value)
        case let .number(value):
            try container.encode(value.doubleValue, forKey: .value)
        case .notFound:
            break
        }
    }
        
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodableKeys.self)
        // Bool
        if let value = try? values.decode(Bool.self, forKey: .value) {
            self = .bool(value)
            return
        }
        // string
        else if let value = try? values.decode(String.self, forKey: .value) {
            self = .string(value)
            return
        }
        // number
        else if let value = try? values.decode(Double.self, forKey: .value) {
            self = .number(NSNumber(value: value))
            return
        } else {
            self = .notFound
            return
        }
    }
}
