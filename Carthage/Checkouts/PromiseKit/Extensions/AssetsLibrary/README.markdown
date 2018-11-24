# PromiseKit AssetsLibrary Extensions ![Build Status]

This project adds promises to Apple’s AssetsLibrary framework.

## CococaPods

```ruby
pod "PromiseKit/AssetsLibrary" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/AssetsLibrary" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKAssetsLibrary
```

```objc
// objc
@import PromiseKit;
@import PMKAssetsLibrary;
```


[Build Status]: https://travis-ci.org/PromiseKit/AssetsLibrary.svg?branch=master
