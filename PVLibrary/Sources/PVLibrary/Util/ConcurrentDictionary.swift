//
//  ConcurrentDictionary.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

public actor ConcurrentDictionary<Key: Hashable, Value>: ExpressibleByDictionaryLiteral,
                                                         @preconcurrency
CustomStringConvertible {
    private var dictionary: [Key: Value] = [:]
    
    public init(dictionaryLiteral elements: (Key, Value)...) {
        dictionary = Dictionary(uniqueKeysWithValues: elements)
    }
    
    public subscript(key: Key) -> Value? {
        get {
            dictionary[key]
        }
        set {
            dictionary[key] = newValue
        }
    }
    
    public func set(_ value: Value?, forKey key: Key) {
        dictionary[key] = value
    }
    
    public var first: (key: Key, value: Value)? {
        dictionary.first
    }
    
    public var isEmpty: Bool {
        dictionary.isEmpty
    }
    
    public var count: Int {
        dictionary.count
    }
    
    public var description: String {
        dictionary.description
    }
}
