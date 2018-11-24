# PromiseKit SystemConfiguration Extensions ![Build Status]

This project adds promises to Apple’s SystemConfiguration framework.

## CocoaPods

```ruby
pod "PromiseKit/SystemConfiguration" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/SystemConfiguration" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKSystemConfiguration
```

```objc
// objc
@import PromiseKit;
@import PMKSystemConfiguration;
```


[Build Status]: https://travis-ci.org/PromiseKit/Foundation.svg?branch=master
