# STALLED

This project is no longer maintained because its promises and API are not up to standard. You can use it, but we will not maintain it unless the API is improved (feel free to PR!).

# PromiseKit EventKit Extensions ![Build Status]

This project adds promises to Apple’s EventKit framework.

## CocoaPods

```ruby
pod "PromiseKit/EventKit" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/EventKit" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKEventKit
```

```objc
// objc
@import PromiseKit;
@import PMKEventKit;
```


[Build Status]: https://travis-ci.org/PromiseKit/EventKit.svg?branch=master
