# PromiseKit MapKit Extensions ![Build Status]

This project adds promises to Apple’s MapKit framework.

## CocoaPods

```ruby
pod "PromiseKit/MapKit", "~> 6.0"
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/MapKit" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKMapKit
```

```objc
// objc
@import PromiseKit;
@import PMKMapKit;
```


[Build Status]: https://travis-ci.org/PromiseKit/MapKit.svg?branch=master
