//
//  ConcurrentSingle.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

/// single value DS that is thread safe
public actor ConcurrentSingle<T> {
    private var _value: T
    
    /// initially set value
    /// - Parameter value: value to set initially
    init(_ value: T) {
        self._value = value
    }
    
    /// gets current value
    var value: T {
        get {
            _value
        }
    }
    
    /// sets new value
    /// - Parameter value: value to set
    func set(value: T) {
        _value = value
    }
    
    var description: String {
        String(describing: _value)
    }
    
}
