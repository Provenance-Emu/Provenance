# PromiseKit MessagesUI Extensions ![Build Status]

This project adds promises to Apple’s MessagesUI framework.

The Objective-C equivalents of this repo are in the UIKit extensions.

## CocoaPods

```ruby
pod "PromiseKit/MessagesUI", "~> 6.0"
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/MessagesUI" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKMessagesUI
```

```objc
// objc
@import PromiseKit;
@import PMKMessagesUI;
```


[Build Status]: https://travis-ci.org/PromiseKit/MessagesUI.svg?branch=master
