# PromiseKit Accounts Extensions ![Build Status]

This project adds promises to Apple’s Accounts framework.

## CococaPods

```ruby
pod "PromiseKit/Accounts" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/Accounts" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKAccounts
```

```objc
// objc
@import PromiseKit;
@import PMKAccounts;
```


[Build Status]: https://travis-ci.org/PromiseKit/Accounts.svg?branch=master
