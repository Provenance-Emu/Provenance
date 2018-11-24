# PromiseKit HealthKit Extensions ![Build Status]

This project adds promises to Apple’s HealthKit framework.

## CocoaPods

```ruby
pod "PromiseKit/HealthKit" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/PMKHealthKit" ~> 1.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKHealthKit
```

```objc
// objc
@import PromiseKit;
@import PMKHealthKit;
```


[Build Status]: https://travis-ci.org/PromiseKit/PMKHealthKit.svg?branch=master
