# PromiseKit UIKit Extensions ![Build Status]

This project adds promises to Apple’s UIKit framework.

This project supports Swift 3.0, 3.1, 3.2 and 4.0; iOS 9, 10 and 11; tvOS 10 and
11; CocoaPods and Carthage; Xcode 8.0, 8.1, 8.2, 8.3 and 9.0.

## CocoaPods

```ruby
pod "PromiseKit/UIKit", "~> 6.0"
```

The extensions are built into `PromiseKit.framework` thus `import PromiseKit` is
all that is needed.

## Carthage

```ruby
github "PromiseKit/UIKit" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKUIKit
```

```objc
// objc
@import PromiseKit;
@import PMKUIKit;
```

# `UIImagePickerController`

Due to iOS 10 requiring an entry in your app’s `Info.plist` for any usage of `UIImagePickerController` (even if you don’t actually call it directly), we have removed UIImagePickerController from the default `UIKit` pod. To use it you must add an additional subspec:

```ruby
pod "PromiseKit/UIImagePickerController"
```

Sorry, but there’s not an easier way.


[Build Status]: https://travis-ci.org/PromiseKit/UIKit.svg?branch=master
