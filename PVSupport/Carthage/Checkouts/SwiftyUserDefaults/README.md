# SwiftyUserDefaults

![Platforms](https://img.shields.io/badge/platforms-ios%20%7C%20osx%20%7C%20watchos%20%7C%20tvos-lightgrey.svg)
[![CI Status](https://api.travis-ci.org/radex/SwiftyUserDefaults.svg?branch=master)](https://travis-ci.org/radex/SwiftyUserDefaults)
[![CocoaPods](http://img.shields.io/cocoapods/v/SwiftyUserDefaults.svg)](https://cocoapods.org/pods/SwiftyUserDefaults)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](#carthage)
![Swift version](https://img.shields.io/badge/swift-3.0-orange.svg)

#### Modern Swift API for `NSUserDefaults`
###### SwiftyUserDefaults makes user defaults enjoyable to use by combining expressive Swifty API with the benefits of static typing. Define your keys in one place, use value types easily, and get extra safety and convenient compile-time checks for free.

Read [Statically-typed NSUserDefaults](http://radex.io/swift/nsuserdefaults/static) for more information about this project.

-------
<p align="center">
    <a href="#features">Features</a> &bull;
    <a href="#usage">Usage</a> &bull;
    <a href="#custom-types">Custom types</a> &bull;
    <a href="#traditional-api">Traditional API</a> &bull; 
    <a href="#installation">Installation</a> &bull; 
    <a href="#more-like-this">More info</a>
</p>
-------

## Features

**There's only two steps to using SwiftyUserDefaults:**

Step 1: Define your keys

```swift
extension DefaultsKeys {
    static let username = DefaultsKey<String?>("username")
    static let launchCount = DefaultsKey<Int>("launchCount")
}
```

Step 2: Just use it!

```swift
// Get and set user defaults easily
let username = Defaults[.username]
Defaults[.hotkeyEnabled] = true

// Modify value types in place
Defaults[.launchCount] += 1
Defaults[.volume] -= 0.1
Defaults[.strings] += "… can easily be extended!"

// Use and modify typed arrays
Defaults[.libraries].append("SwiftyUserDefaults")
Defaults[.libraries][0] += " 2.0"

// Easily work with custom serialized types
Defaults[.color] = NSColor.white
Defaults[.color]?.whiteComponent // => 1.0
```

The convenient dot syntax is only available if you define your keys by extending magic `DefaultsKeys` class. You can also just pass the `DefaultsKey` value in square brackets, or use a more traditional string-based API. How? Keep reading.

## Usage

### Define your keys

To get the most out of SwiftyUserDefaults, define your user defaults keys ahead of time:

```swift
let colorKey = DefaultsKey<String>("color")
```

Just create a `DefaultsKey` object, put the type of the value you want to store in angle brackets, the key name in parentheses, and you're good to go.

You can now use the `Defaults` shortcut to access those values:

```swift
Defaults[colorKey] = "red"
Defaults[colorKey] // => "red", typed as String
```

The compiler won't let you set a wrong value type, and fetching conveniently returns `String`.

### Take shortcuts

For extra convenience, define your keys by extending magic `DefaultsKeys` class and adding static properties:

```swift
extension DefaultsKeys {
    static let username = DefaultsKey<String?>("username")
    static let launchCount = DefaultsKey<Int>("launchCount")
}
```

And use the shortcut dot syntax:

```swift
Defaults[.username] = "joe"
Defaults[.launchCount]
```

### Just use it!

You can easily modify value types (strings, numbers, array) in place, as if you were working with a plain old dictionary:

```swift
// Modify value types in place
Defaults[.launchCount] += 1
Defaults[.volume] -= 0.1
Defaults[.strings] += "… can easily be extended!"

// Use and modify typed arrays
Defaults[.libraries].append("SwiftyUserDefaults")
Defaults[.libraries][0] += " 2.0"

// Easily work with custom serialized types
Defaults[.color] = NSColor.white
Defaults[.color]?.whiteComponent // => 1.0
```

### Supported types

SwiftyUserDefaults supports all of the standard `NSUserDefaults` types, like strings, numbers, booleans, arrays and dictionaries.

Here's a full table:

| Optional variant       | Non-optional variant  | Default value |
|------------------------|-----------------------|---------------|
| `String?`              | `String`              | `""`          |
| `Int?`                 | `Int`                 | `0`           |
| `Double?`              | `Double`              | `0.0`         |
| `Bool?`                | `Bool`                | `false`       |
| `Data?`                | `Data`                | `Data()`      |
| `[Any]?`               | `[Any]`               | `[]`          |
| `[String: Any]?`       | `[String: Any]`       | `[:]`         |
| `Date?`                | n/a                   | n/a           |
| `URL?`                 | n/a                   | n/a           |
| `Any?`                 | n/a                   | n/a           |

You can mark a type as optional to get `nil` if the key doesn't exist. Otherwise, you'll get a default value that makes sense for a given type.

#### Typed arrays

Additionally, typed arrays are available for these types:

| Array type | Optional variant |
|------------|------------------|
| `[String]` | `[String]?`      |
| `[Int]`    | `[Int]?`         |
| `[Double]` | `[Double]?`      |
| `[Bool]`   | `[Bool]?`        |
| `[Data]`   | `[Data]?`        |
| `[Date]`   | `[Date]?`        |

### Custom types

You can easily store custom `NSCoding`-compliant types by extending `UserDefaults` with this stub subscript:

```swift
extension UserDefaults {
    subscript(key: DefaultsKey<NSColor?>) -> NSColor? {
        get { return unarchive(key) }
        set { archive(key, newValue) }
    }
}
```

Just copy&paste this and change `NSColor` to your class name.

Here's a usage example:

```swift
extension DefaultsKeys {
    static let color = DefaultsKey<NSColor?>("color")
}

Defaults[.color] // => nil
Defaults[.color] = NSColor.white
Defaults[.color] // => w 1.0, a 1.0
Defaults[.color]?.whiteComponent // => 1.0
```

#### Custom types with default values

If you don't want to deal with `nil` when fetching a user default value, you can remove `?` marks and supply the default value, like so:

```swift
extension UserDefaults {
    subscript(key: DefaultsKey<NSColor>) -> NSColor {
        get { return unarchive(key) ?? NSColor.clear }
        set { archive(key, newValue) }
    }
}
```

#### Enums

In addition to `NSCoding`, you can store `enum` values the same way:

```swift
enum MyEnum: String {
    case A, B, C
}

extension UserDefaults {
    subscript(key: DefaultsKey<MyEnum?>) -> MyEnum? {
        get { return unarchive(key) }
        set { archive(key, newValue) }
    }
}
```

The only requirement is that the enum has to be `RawRepresentable` by a simple type like `String` or `Int`.

### Existence

```swift
if !Defaults.hasKey(.hotkey) {
    Defaults.remove(.hotkeyOptions)
}
```

You can use the `hasKey` method to check for key's existence in the user defaults. `remove()` is an alias for `removeObjectForKey()`, that also works with `DefaultsKeys` shortcuts.

### Remove all keys

To reset user defaults, use `removeAll` method.

```swift
Defaults.removeAll()
```

### Shared user defaults

If you're sharing your user defaults between different apps or an app and its extensions, you can use SwiftyUserDefaults by overriding the `Defaults` shortcut with your own. Just add in your app:

```swift
var Defaults = UserDefaults(suiteName: "com.my.app")!
```

## Traditional API

There's also a more traditional string-based API available. This is considered legacy API, and it's recommended that you use statically defined keys instead.

```swift
Defaults["color"].string            // returns String?
Defaults["launchCount"].int         // returns Int?
Defaults["chimeVolume"].double      // returns Double?
Defaults["loggingEnabled"].bool     // returns Bool?
Defaults["lastPaths"].array         // returns [Any]?
Defaults["credentials"].dictionary  // returns [String: Any]?
Defaults["hotkey"].data             // returns Data?
Defaults["firstLaunchAt"].date      // returns Date?
Defaults["anything"].object         // returns Any?
Defaults["anything"].number         // returns NSNumber?
```

When you don't want to deal with the `nil` case, you can use these helpers that return a default value for non-existing defaults:

```swift
Defaults["color"].stringValue            // defaults to ""
Defaults["launchCount"].intValue         // defaults to 0
Defaults["chimeVolume"].doubleValue      // defaults to 0.0
Defaults["loggingEnabled"].boolValue     // defaults to false
Defaults["lastPaths"].arrayValue         // defaults to []
Defaults["credentials"].dictionaryValue  // defaults to [:]
Defaults["hotkey"].dataValue             // defaults to Data()
```

## Installation

**Note:** If you're running Swift 2, use [SwiftyUserDefaults v2.2.1](https://github.com/radex/SwiftyUserDefaults/tree/2.2.1)

#### CocoaPods

If you're using CocoaPods, just add this line to your Podfile:

```ruby
pod 'SwiftyUserDefaults'
```

Install by running this command in your terminal:

```sh
pod install
```

Then import the library in all files where you use it:

```swift
import SwiftyUserDefaults
```

#### Carthage

Just add to your Cartfile:

```ruby
github "radex/SwiftyUserDefaults"
```

#### Manually

Simply copy `Sources/SwiftyUserDefaults.swift` to your Xcode project.

## More like this

If you like SwiftyUserDefaults, check out [SwiftyTimer](https://github.com/radex/SwiftyTimer), which applies the same swifty approach to `NSTimer`.

You might also be interested in my blog posts which explain the design process behind those libraries:
- [Swifty APIs: NSUserDefaults](http://radex.io/swift/nsuserdefaults/)
- [Statically-typed NSUserDefaults](http://radex.io/swift/nsuserdefaults/static)
- [Swifty APIs: NSTimer](http://radex.io/swift/nstimer/)
- [Swifty methods](http://radex.io/swift/methods/)

### Contributing

If you have comments, complaints or ideas for improvements, feel free to open an issue or a pull request. Or [ping me on Twitter](http://twitter.com/radexp).

### Author and license

Radek Pietruszewski

* [github.com/radex](http://github.com/radex)
* [twitter.com/radexp](http://twitter.com/radexp)
* [radex.io](http://radex.io)
* this.is@radex.io

SwiftyUserDefaults is available under the MIT license. See the LICENSE file for more info.
