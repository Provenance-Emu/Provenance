# PromiseKit StoreKit Extensions ![Build Status]

This project adds promises to Apple’s StoreKit framework.

## CocoaPods

```ruby
pod "PromiseKit/StoreKit", "~> 6.0"
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/StoreKit" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKStoreKit
```

```objc
// objc
@import PromiseKit;
@import PMKStoreKit;
```


[Build Status]: https://travis-ci.org/PromiseKit/StoreKit.svg?branch=master
