# DEPRECATED

Use PMKFoundation or PMKAlamofire, the promises provided by this repository are minimal
and add little value over just using OMG by itself and passing its URLRequests to
URLSession manually.

# PromiseKit OMGHTTPURLRQ Extensions ![Build Status]

This project provides convenience methods on NSURLSession using [OMGHTTPURLRQ].

## Usage

```swift
URLSession.shared.POST(url, formData: params).then { data -> Void in
    // by default you just get the raw `Data`
}

URLSession.shared.GET(url).asDictionary().then { json -> Void in
    // call `asDictionary()` to have the result decoded
    // as JSON with the result being an `NSDictionary`
    // the promise is rejected if the JSON can not be
    // decoded or the resulting object is not a dictionary
}

URLSession.shared.PUT(url, json: params).asArray().then { json -> Void in
    // json: NSArray
}

URLSession.shared.DELETE(url).asString().then { string -> Void in
    // string: String
}
```

## CocoaPods

```ruby
pod "PromiseKit/OMGHTTPURLRQ", "~> 6.0"
```

The extensions are built into `PromiseKit.framework` thus nothing else is needed.

## Carthage

```ruby
github "PromiseKit/OMGHTTPURLRQ-" ~> 3.0
```

The extensions are built into their own framework:

```swift
// swift
import PromiseKit
import OMGHTTPURLRQ
import PMKOMGHTTPURLRQ
```

```objc
// objc
@import PromiseKit;
@import OMGHTTPURLRQ;
@import PMKOMGHTTPURLRQ;
```


[Build Status]: https://travis-ci.org/PromiseKit/OMGHTTPURLRQ.svg?branch=master
