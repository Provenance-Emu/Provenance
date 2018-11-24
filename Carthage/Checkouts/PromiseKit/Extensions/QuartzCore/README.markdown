# PromiseKit QuartzCore Extensions ![Build Status]

This project adds promises to Apple’s QuartzCore framework.

## CocoaPods

```ruby
pod "PromiseKit/QuartzCore" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/QuartzCore" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKQuartzCore
```

```objc
// objc
@import PromiseKit;
@import PMKQuartzCore;
```


[Build Status]: https://travis-ci.org/PromiseKit/QuartzCore.svg?branch=master
