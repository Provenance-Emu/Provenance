# PromiseKit Social Extensions ![Build Status]

This project adds promises to Apple’s Social framework.

## CocoaPods

```ruby
pod "PromiseKit/Social", "~> 6.0"
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/Social" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKSocial
```

```objc
// objc
@import PromiseKit;
@import PMKSocial;
```


[Build Status]: https://travis-ci.org/PromiseKit/Social.svg?branch=master
