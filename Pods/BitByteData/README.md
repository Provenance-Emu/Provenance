# BitByteData

[![Swift 4.2](https://img.shields.io/badge/Swift-4.2-blue.svg)](https://developer.apple.com/swift/)
[![Swift 5.X](https://img.shields.io/badge/Swift-/5.X-blue.svg)](https://developer.apple.com/swift/)
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/tsolomko/BitByteData/master/LICENSE)
[![Build Status](https://travis-ci.com/tsolomko/BitByteData.svg?branch=develop)](https://travis-ci.com/tsolomko/BitByteData)

A Swift framework with classes for reading and writing bits and bytes.

## Installation

BitByteData can be integrated into your project using Swift Package Manager, CocoaPods or Carthage.

### Swift Package Manager

To install using SPM, add BitByteData to you package dependencies and specify it as a dependency for your target, e.g.:

```swift
import PackageDescription

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(url: "https://github.com/tsolomko/BitByteData.git",
                 from: "1.4.0")
    ],
    targets: [
        .target(
            name: "TargetName",
            dependencies: ["BitByteData"]
        )
    ]
)
```

More details you can find in [Swift Package Manager's Documentation](https://github.com/apple/swift-package-manager/tree/master/Documentation).

### CocoaPods

Add `pod 'BitByteData', '~> 1.4'` and `use_frameworks!` lines to your Podfile.

To complete installation, run `pod install`.

### Carthage

__Important:__ Only Swift 5.x is supported when installing BitByteData via Carthage.

Add to your Cartfile `github "tsolomko/BitByteData" ~> 1.4`.

Then run `carthage update`.

Finally, drag and drop `BitByteData.framework` from `Carthage/Build` folder into the "Embedded Binaries" section on your
targets' "General" tab in Xcode.

## Usage

Use `ByteReader` class to read bytes.
For reading bits there are two classes: `LsbBitReader` and `MsbBitReader`, which implement `BitReader` protocol
for two bit-numbering schemes ("LSB 0" and "MSB 0" correspondingly).
Both `LsbBitReader` and `MsbBitReader` classes inherit from `ByteReader` so you can also use them to read bytes
(but they must be aligned, see documentation for more details).

Writing bits is implemented in two classes `LsbBitWriter` and `MsbBitWriter` (again, for two bit-numbering schemes).
They both conform to `BitWriter` protocol.

__Note:__ All readers and writers aren't structs, but classes intentionally to make it easier to pass them as arguments
to functions and to eliminate unnecessary copying and `inout`s.

## Documentation

Every function or type of BitByteData's public API is documented.
This documentation can be found at its own [website](http://tsolomko.github.io/BitByteData).

## Contributing

Whether you find a bug, have a suggestion, idea, feedback or something else, please
[create an issue](https://github.com/tsolomko/BitByteData/issues) on GitHub.

If you'd like to contribute, please [create a pull request](https://github.com/tsolomko/BitByteData/pulls) on GitHub.

__Note:__ If you are considering working on BitByteData, please note that Xcode project (BitByteData.xcodeproj)
was created manually and you shouldn't use `swift package generate-xcodeproj` command.

### Performance and benchmarks

One of the most important goals of BitByteData's development is high speed performance. To help achieve this goal there
are benchmarks for every function in the project as well as a handy command-line tool, `benchmarks.py`, which helps to
run, show, and compare benchmarks and their results.

If you are considering contributing to the project please make sure that:

1. Every new function has also a new benchmark added.
2. Every other change to any existing function doesn't introduce performance regressions, or, at the very least, these
   regressions are small and such performance tradeoff is necessary and justifiable.

Finally, please note that any meaningful comparison can be made only between benchmarks run on the same hardware and
software.
