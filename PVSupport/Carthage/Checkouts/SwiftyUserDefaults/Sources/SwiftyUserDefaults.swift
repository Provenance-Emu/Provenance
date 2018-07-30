//
// SwiftyUserDefaults
//
// Copyright (c) 2015-2016 Radosław Pietruszewski
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation

public extension UserDefaults {
    class Proxy {
        fileprivate let defaults: UserDefaults
        fileprivate let key: String
        
        fileprivate init(_ defaults: UserDefaults, _ key: String) {
            self.defaults = defaults
            self.key = key
        }
        
        // MARK: Getters
        
        public var object: Any? {
            return defaults.object(forKey: key)
        }
        
        public var string: String? {
            return defaults.string(forKey: key)
        }
        
        public var array: [Any]? {
            return defaults.array(forKey: key)
        }
        
        public var dictionary: [String: Any]? {
            return defaults.dictionary(forKey: key)
        }
        
        public var data: Data? {
            return defaults.data(forKey: key)
        }
        
        public var date: Date? {
            return object as? Date
        }
        
        public var number: NSNumber? {
            return defaults.numberForKey(key)
        }
        
        public var int: Int? {
            return number?.intValue
        }
        
        public var double: Double? {
            return number?.doubleValue
        }
        
        public var bool: Bool? {
            return number?.boolValue
        }
        
        // MARK: Non-Optional Getters
        
        public var stringValue: String {
            return string ?? ""
        }
        
        public var arrayValue: [Any] {
            return array ?? []
        }
        
        public var dictionaryValue: [String: Any] {
            return dictionary ?? [:]
        }
        
        public var dataValue: Data {
            return data ?? Data()
        }
        
        public var numberValue: NSNumber {
            return number ?? 0
        }
        
        public var intValue: Int {
            return int ?? 0
        }
        
        public var doubleValue: Double {
            return double ?? 0
        }
        
        public var boolValue: Bool {
            return bool ?? false
        }
    }
    
    /// `NSNumber` representation of a user default
    
    func numberForKey(_ key: String) -> NSNumber? {
        return object(forKey: key) as? NSNumber
    }
    
    /// Returns getter proxy for `key`
    
    public subscript(key: String) -> Proxy {
        return Proxy(self, key)
    }
    
    /// Sets value for `key`
    
    public subscript(key: String) -> Any? {
        get {
            // return untyped Proxy
            // (make sure we don't fall into infinite loop)
            let proxy: Proxy = self[key]
            return proxy
        }
        set {
            
            guard let newValue = newValue else {
                removeObject(forKey: key)
                return
            }
            
            switch newValue {
            // @warning This should always be on top of Int because a cast
            // from Double to Int will always succeed.
            case let v as Double: self.set(v, forKey: key)
            case let v as Int: self.set(v, forKey: key)
            case let v as Bool: self.set(v, forKey: key)
            case let v as URL: self.set(v, forKey: key)
            default: self.set(newValue, forKey: key)
            }
        }
    }
    
    /// Returns `true` if `key` exists
    
    public func hasKey(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }
    
    /// Removes value for `key`
    
    public func remove(_ key: String) {
        removeObject(forKey: key)
    }
    
    /// Removes all keys and values from user defaults
    /// Use with caution!
    /// - Note: This method only removes keys on the receiver `UserDefaults` object.
    ///         System-defined keys will still be present afterwards.
    
    public func removeAll() {
        for (key, _) in dictionaryRepresentation() {
            removeObject(forKey: key)
        }
    }
}

/// Global shortcut for `UserDefaults.standard`
///
/// **Pro-Tip:** If you want to use shared user defaults, just
///  redefine this global shortcut in your app target, like so:
///  ~~~
///  var Defaults = UserDefaults(suiteName: "com.my.app")!
///  ~~~

public let Defaults = UserDefaults.standard

// MARK: - Static keys

/// Extend this class and add your user defaults keys as static constants
/// so you can use the shortcut dot notation (e.g. `Defaults[.yourKey]`)

public class DefaultsKeys {
    fileprivate init() {}
}

/// Base class for static user defaults keys. Specialize with value type
/// and pass key name to the initializer to create a key.

public class DefaultsKey<ValueType>: DefaultsKeys {
    // TODO: Can we use protocols to ensure ValueType is a compatible type?
    public let _key: String
    
    public init(_ key: String) {
        self._key = key
        super.init()
    }
}

extension UserDefaults {
    /// This function allows you to create your own custom Defaults subscript. Example: [Int: String]
    public func set<T>(_ key: DefaultsKey<T>, _ value: Any?) {
        self[key._key] = value
    }
}

extension UserDefaults {
    /// Returns `true` if `key` exists
    
    public func hasKey<T>(_ key: DefaultsKey<T>) -> Bool {
        return object(forKey: key._key) != nil
    }
    
    /// Removes value for `key`
    
    public func remove<T>(_ key: DefaultsKey<T>) {
        removeObject(forKey: key._key)
    }
}

// MARK: Subscripts for specific standard types

// TODO: Use generic subscripts when they become available

extension UserDefaults {
    public subscript(key: DefaultsKey<String?>) -> String? {
        get { return string(forKey: key._key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<String>) -> String {
        get { return string(forKey: key._key) ?? "" }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Int?>) -> Int? {
        get { return numberForKey(key._key)?.intValue }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Int>) -> Int {
        get { return numberForKey(key._key)?.intValue ?? 0 }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Double?>) -> Double? {
        get { return numberForKey(key._key)?.doubleValue }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Double>) -> Double {
        get { return numberForKey(key._key)?.doubleValue ?? 0.0 }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Bool?>) -> Bool? {
        get { return numberForKey(key._key)?.boolValue }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Bool>) -> Bool {
        get { return numberForKey(key._key)?.boolValue ?? false }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Any?>) -> Any? {
        get { return object(forKey: key._key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Data?>) -> Data? {
        get { return data(forKey: key._key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Data>) -> Data {
        get { return data(forKey: key._key) ?? Data() }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<Date?>) -> Date? {
        get { return object(forKey: key._key) as? Date }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<URL?>) -> URL? {
        get { return url(forKey: key._key) }
        set { set(key, newValue) }
    }
    
    // TODO: It would probably make sense to have support for statically typed dictionaries (e.g. [String: String])
    
    public subscript(key: DefaultsKey<[String: Any]?>) -> [String: Any]? {
        get { return dictionary(forKey: key._key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[String: Any]>) -> [String: Any] {
        get { return dictionary(forKey: key._key) ?? [:] }
        set { set(key, newValue) }
    }
}

// MARK: Static subscripts for array types

extension UserDefaults {
    public subscript(key: DefaultsKey<[Any]?>) -> [Any]? {
        get { return array(forKey: key._key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Any]>) -> [Any] {
        get { return array(forKey: key._key) ?? [] }
        set { set(key, newValue) }
    }
}

// We need the <T: AnyObject> and <T: _ObjectiveCBridgeable> variants to
// suppress compiler warnings about NSArray not being convertible to [T]
// AnyObject is for NSData and NSDate, _ObjectiveCBridgeable is for value
// types bridge-able to Foundation types (String, Int, ...)

extension UserDefaults {
    public func getArray<T: _ObjectiveCBridgeable>(_ key: DefaultsKey<[T]>) -> [T] {
        return array(forKey: key._key) as NSArray? as? [T] ?? []
    }
    
    public func getArray<T: _ObjectiveCBridgeable>(_ key: DefaultsKey<[T]?>) -> [T]? {
        return array(forKey: key._key) as NSArray? as? [T]
    }
    
    public func getArray<T: Any>(_ key: DefaultsKey<[T]>) -> [T] {
        return array(forKey: key._key) as NSArray? as? [T] ?? []
    }
    
    public func getArray<T: Any>(_ key: DefaultsKey<[T]?>) -> [T]? {
        return array(forKey: key._key) as NSArray? as? [T]
    }
}

extension UserDefaults {
    public subscript(key: DefaultsKey<[String]?>) -> [String]? {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[String]>) -> [String] {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Int]?>) -> [Int]? {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Int]>) -> [Int] {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Double]?>) -> [Double]? {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Double]>) -> [Double] {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Bool]?>) -> [Bool]? {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Bool]>) -> [Bool] {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Data]?>) -> [Data]? {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Data]>) -> [Data] {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Date]?>) -> [Date]? {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
    
    public subscript(key: DefaultsKey<[Date]>) -> [Date] {
        get { return getArray(key) }
        set { set(key, newValue) }
    }
}

// MARK: - Archiving custom types

// MARK: RawRepresentable

extension UserDefaults {
    // TODO: Ensure that T.RawValue is compatible
    public func archive<T: RawRepresentable>(_ key: DefaultsKey<T>, _ value: T) {
        set(key, value.rawValue)
    }
    
    public func archive<T: RawRepresentable>(_ key: DefaultsKey<T?>, _ value: T?) {
        if let value = value {
            set(key, value.rawValue)
        } else {
            remove(key)
        }
    }
    
    public func unarchive<T: RawRepresentable>(_ key: DefaultsKey<T?>) -> T? {
        return object(forKey: key._key).flatMap { T(rawValue: $0 as! T.RawValue) }
    }
    
    public func unarchive<T: RawRepresentable>(_ key: DefaultsKey<T>) -> T? {
        return object(forKey: key._key).flatMap { T(rawValue: $0 as! T.RawValue) }
    }
}

// MARK: NSCoding

extension UserDefaults {
    // TODO: Can we simplify this and ensure that T is NSCoding compliant?

    public func archive<T>(_ key: DefaultsKey<T>, _ value: T) {
        set(key, NSKeyedArchiver.archivedData(withRootObject: value))
    }

    public func archive<T>(_ key: DefaultsKey<T?>, _ value: T?) {
        if let value = value {
            set(key, NSKeyedArchiver.archivedData(withRootObject: value))
        } else {
            remove(key)
        }
    }
    
    public func unarchive<T>(_ key: DefaultsKey<T>) -> T? {
        return data(forKey: key._key).flatMap { NSKeyedUnarchiver.unarchiveObject(with: $0) } as? T
    }
    
    public func unarchive<T>(_ key: DefaultsKey<T?>) -> T? {
        return data(forKey: key._key).flatMap { NSKeyedUnarchiver.unarchiveObject(with: $0) } as? T
    }
}

// MARK: - Deprecations

infix operator ?= : AssignmentPrecedence

/// If key doesn't exist, sets its value to `expr`
/// - Deprecation: This will be removed in a future release.
///   Please migrate to static keys and use this gist: https://gist.github.com/radex/68de9340b0da61d43e60
/// - Note: This isn't the same as `Defaults.registerDefaults`. This method saves the new value to disk, whereas `registerDefaults` only modifies the defaults in memory.
/// - Note: If key already exists, the expression after ?= isn't evaluated

@available(*, deprecated:1, message:"Please migrate to static keys and use this gist: https://gist.github.com/radex/68de9340b0da61d43e60")
public func ?= (proxy: UserDefaults.Proxy, expr: @autoclosure() -> Any) {
    if !proxy.defaults.hasKey(proxy.key) {
        proxy.defaults[proxy.key] = expr()
    }
}

/// Adds `b` to the key (and saves it as an integer)
/// If key doesn't exist or isn't a number, sets value to `b`

@available(*, deprecated:1, message:"Please migrate to static keys to use this.")
public func += (proxy: UserDefaults.Proxy, b: Int) {
    let a = proxy.defaults[proxy.key].intValue
    proxy.defaults[proxy.key] = a + b
}

@available(*, deprecated:1, message:"Please migrate to static keys to use this.")
public func += (proxy: UserDefaults.Proxy, b: Double) {
    let a = proxy.defaults[proxy.key].doubleValue
    proxy.defaults[proxy.key] = a + b
}

/// Icrements key by one (and saves it as an integer)
/// If key doesn't exist or isn't a number, sets value to 1

@available(*, deprecated:1, message:"Please migrate to static keys to use this.")
public postfix func ++ (proxy: UserDefaults.Proxy) {
    proxy += 1
}
