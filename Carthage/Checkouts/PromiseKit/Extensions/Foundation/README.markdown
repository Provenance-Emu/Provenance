# PromiseKit Foundation Extensions ![Build Status]

This project adds promises to the Swift Foundation framework.

We support iOS, tvOS, watchOS, macOS and Linux, Swift 3.0, 3.1, 3.2, 4.0 and 4.1.

## CococaPods

```ruby
pod "PromiseKit/Foundation", "~> 6.0"
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/Foundation" ~> 3.0
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
@import PMKFoundation;
```

## SwiftPM

```swift
let package = Package(
    dependencies: [
        .Package(url: "https://github.com/PromiseKit/Foundation.git", majorVersion: 3)
    ]
)
```


[Build Status]: https://travis-ci.org/PromiseKit/Foundation.svg?branch=master
