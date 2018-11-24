# PromiseKit AVFoundation Extensions ![Build Status]

This project adds promises to Apple’s AVFoundation framework.

## CococaPods

```ruby
pod "PromiseKit/AVFoundation" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/AVFoundation" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKAVFoundation
```

```objc
// objc
@import PromiseKit;
@import PMKAVFoundation;
```


[Build Status]: https://travis-ci.org/PromiseKit/AVFoundation.svg?branch=master
