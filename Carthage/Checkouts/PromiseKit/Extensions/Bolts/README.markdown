# PromiseKit Bolts Extensions ![Build Status]

This project adds promises to Facebook’s [Bolts] framework.

Bolts underlies the entire Facbook SDK.

## Usage

```swift
someBoltsTask().then { anyObject in
    //…
}
```

## CocoaPods

```ruby
pod "PromiseKit/Bolts" ~> 6.0
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/Bolts" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import PMKBolts
```

```objc
// objc
@import PromiseKit;
@import PMKBolts;
```


[Bolts]: https://github.com/BoltsFramework


[Build Status]: https://travis-ci.org/PromiseKit/Bolts.svg?branch=master
