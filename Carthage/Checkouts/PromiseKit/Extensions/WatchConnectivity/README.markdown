# PromiseKit WatchConnectivity Extensions ![Build Status]

This project adds promises to Apple’s WatchConnectivity framework.

## CocoaPods

```ruby
pod "PromiseKit/WatchConnectivity" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/WatchConnectivity" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKWatchConnectivity
```

```objc
// objc
@import PromiseKit;
@import PMKWatchConnectivity;
```


[Build Status]: https://travis-ci.org/PromiseKit/WatchConnectivity.svg?branch=master
