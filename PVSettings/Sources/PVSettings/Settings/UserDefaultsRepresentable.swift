//
//  UserDefaultsRepresentable.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/8/24.
//


public protocol UserDefaultsRepresentable {
    var valueType: Any.Type { get }
    var defaultsValue: Any { get }
}

extension UserDefaultsRepresentable where Self: RawRepresentable {
    public var valueType: Any.Type {
        return type(of: self) // RawValue.self
    }
    
    public var defaultsValue: Any {
        return rawValue
    }
}

// Add Set support
extension Set: UserDefaultsRepresentable {
    public var valueType: Any.Type {
        return [Element].self
    }

    public var defaultsValue: Any {
        return Array(self)
    }
}
