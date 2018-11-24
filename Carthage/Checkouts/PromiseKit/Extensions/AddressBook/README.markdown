# PromiseKit AddressBook Extensions ![Build Status]

This project adds promises to Apple’s AddressBook framework.

## CococaPods

```ruby
pod "PromiseKit/AddressBook" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/AddressBook" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKAddressBook
```

```objc
// objc
@import PromiseKit;
@import PMKAddressBook;
```


[Build Status]: https://travis-ci.org/PromiseKit/AddressBook.svg?branch=master
