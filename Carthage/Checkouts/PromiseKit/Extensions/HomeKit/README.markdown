# PromiseKit HomeKit Extensions ![Build Status]

This project adds promises to Apple’s HomeKit framework.

* Xcode >= 9.3 required for iOS
* Xcode >= 9.0 required for all other platforms

Thus, Swift versions supported are: 3.2, 3.3, 3.4, 4.0, 4.1 & 4.2.

## CocoaPods

```ruby
pod "PromiseKit/HomeKit", "~> 6.0"
```

The extensions are built into PromiseKit.framework thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/HomeKit" ~> 1.0
```

The extension is built into it's own framework:

```swift
import PromiseKit
import PMKHomeKit
```


[Build Status]: https://travis-ci.org/chrischares/PromiseKit-HomeKit.svg?branch=master
