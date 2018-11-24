# PromiseKit CloudKit Extensions ![Build Status]

This project adds promises to Apple’s CloudKit framework.

## CococaPods

```ruby
pod "PromiseKit/CloudKit" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/CloudKit" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKFoundation
```

```objc
// objc
@import PromiseKit;
@import PMKCloudKit;
```


[Build Status]: https://travis-ci.org/PromiseKit/CloudKit.svg?branch=master
