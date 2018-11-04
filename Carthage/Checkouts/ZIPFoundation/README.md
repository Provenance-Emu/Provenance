<img src="https://user-images.githubusercontent.com/1577319/27564151-1d99e3a0-5ad6-11e7-8ab6-417c5b5a3ff2.png" width="489"/>

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/ZIPFoundation.svg)](https://cocoapods.org/pods/ZIPFoundation)
[![Platform](https://img.shields.io/cocoapods/p/ZIPFoundation.svg?style=flat)](http://cocoadocs.org/docsets/ZIPFoundation)
[![Twitter](https://img.shields.io/badge/twitter-@weichsel-blue.svg?style=flat)](http://twitter.com/weichsel)

ZIP Foundation is a library to create, read and modify ZIP archive files.  
It is written in Swift and based on [Apple's libcompression](https://developer.apple.com/documentation/compression/data_compression) for high performance and energy efficiency.  
To learn more about the performance characteristics of the framework, you can read [this blog post](https://thomas.zoechling.me/journal/2017/07/ZIPFoundation.html).

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
    - [Zipping Files and Directories](#zipping-files-and-directories)
    - [Unzipping Archives](#unzipping-archives)
- [Advanced Usage](#advanced-usage)
    - [Accessing individual Entries](#accessing-individual-entries)
    - [Creating Archives](#creating-archives)
    - [Adding and Removing Entries](#adding-and-removing-entries)
    - [Closure based Reading and Writing](#closure-based-reading-and-writing)
	- [Progress Tracking and Cancellation](#progress-tracking-and-cancellation)
- [Credits](#credits)
- [License](#license)

## Features

- [x] Modern Swift API
- [x] High Performance Compression and Decompression
- [x] Deterministic Memory Consumption
- [x] Linux compatibility
- [x] No 3rd party dependencies (on Apple platforms, zlib on Linux)
- [x] Comprehensive Unit and Performance Test Coverage
- [x] Complete Documentation

## Requirements

- iOS 9.0+ / macOS 10.11+ / tvOS 9.0+ / watchOS 2.0+
- Or Linux with zlib development package
- Xcode 9.0
- Swift 4.0

## Installation

### Swift Package Manager
Swift Package Manager is a dependency manager currently under active development. To learn how to use the Swift Package Manager for your project, please read the [official documentation](https://github.com/apple/swift-package-manager/blob/master/Documentation/Usage.md).  
The ZIP Foundation package uses the [V4 Package Description API](https://github.com/apple/swift-package-manager/blob/master/Documentation/PackageDescriptionV4.md).
To add ZIP Foundation as a dependency, you have to add it to the `dependencies` of your `Package.swift` file and refer to that dependency in your `target`.

```swift
// swift-tools-version:4.0
import PackageDescription
let package = Package(
    name: "<Your Product Name>",
    dependencies: [
		.package(url: "https://github.com/weichsel/ZIPFoundation/", .upToNextMajor(from: "0.9.0"))
    ],
    targets: [
        .target(
		name: "<Your Target Name>",
		dependencies: ["ZIPFoundation"]),
    ]
)
```

After adding the dependency, you can fetch the library with:

```bash
$ swift package resolve
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager.  
Installation instructions can be found in the project's [README file](https://github.com/Carthage/Carthage#installing-carthage).

To integrate ZIPFoundation into your Xcode project using Carthage, you have to add it to your `Cartfile`:

```ogdl
github "weichsel/ZIPFoundation" ~> 0.9
```

After adding ZIPFoundation to the `Cartfile`, you have to fetch the sources by running:

```bash
carthage update --no-build
```

The fetched project has to be integrated into your workspace by dragging `ZIPFoundation.xcodeproj` to Xcode's Project Navigator. (See [official Carhage docs](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application).)

### CocoaPods

CocoaPods is a dependency manager for Objective-C and Swift.  
To learn more about setting up your project for CocoaPods, please refer to the [official documentation](https://cocoapods.org/#install).  
To integrate ZIP Foundation into your Xcode project using CocoaPods, you have to add it to your project's `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!
target '<Your Target Name>' do
    pod 'ZIPFoundation', '~> 0.9'
end
```

Afterwards, run the following command:

```bash
$ pod install
```

## Usage
ZIP Foundation provides two high level methods to zip and unzip items. Both are implemented as extension of `FileManager`.  
The functionality of those methods is modeled after the behavior of the Archive Utility in macOS.  

### Zipping Files and Directories
To zip a single file you simply pass a file URL representing the item you want to zip and a destination URL to `FileManager.zipItem(at sourceURL: URL, to destinationURL: URL)`:

```swift
let fileManager = FileManager()
let currentWorkingPath = fileManager.currentDirectoryPath
var sourceURL = URL(fileURLWithPath: currentWorkingPath)
sourceURL.appendPathComponent("file.txt")
var destinationURL = URL(fileURLWithPath: currentWorkingPath)
destinationURL.appendPathComponent("archive.zip")
do {
    try fileManager.zipItem(at: sourceURL, to: destinationURL)
} catch {
    print("Creation of ZIP archive failed with error:\(error)")
}
```

The same method also accepts URLs that represent directory items. In that case, `zipItem` adds the directory content of `sourceURL` to the archive.  
By default, a root directory entry named after the `lastPathComponent` of the `sourceURL` is added to the destination archive.  If you don't want to preserve the parent directory of the source in your archive, you can pass `shouldKeepParent: false`.

### Unzipping Archives
To unzip existing archives, you can use `FileManager.unzipItem(at sourceURL: URL, to destinationURL: URL)`.  
This recursively extracts all entries within the archive to the destination URL:

```swift
let fileManager = FileManager()
let currentWorkingPath = fileManager.currentDirectoryPath
var sourceURL = URL(fileURLWithPath: currentWorkingPath)
sourceURL.appendPathComponent("archive.zip")
var destinationURL = URL(fileURLWithPath: currentWorkingPath)
destinationURL.appendPathComponent("directory")
do {
    try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
    try fileManager.unzipItem(at: sourceURL, to: destinationURL)
} catch {
    print("Extraction of ZIP archive failed with error:\(error)")
}
```

## Advanced Usage
ZIP Foundation also allows you to individually access specific entries without the need to extract the whole archive. Additionally it comes with the ability to incrementally update archive contents.

### Accessing individual Entries
To gain access to specific ZIP entries, you have to initialize an `Archive` object with a file URL that represents an existing archive. After doing that, entries can be retrieved via their relative path. `Archive` conforms to `Sequence` and therefore supports subscripting:

```swift
let fileManager = FileManager()
let currentWorkingPath = fileManager.currentDirectoryPath
var archiveURL = URL(fileURLWithPath: currentWorkingPath)
archiveURL.appendPathComponent("archive.zip")
guard let archive = Archive(url: archiveURL, accessMode: .read) else  {
    return
}
guard let entry = archive["file.txt"] else {
    return
}
var destinationURL = URL(fileURLWithPath: currentWorkingPath)
destinationURL.appendPathComponent("out.txt")
do {
    try archive.extract(entry, to: destinationURL)
} catch {
    print("Extracting entry from archive failed with error:\(error)")
}
```

The `extract` method accepts optional parameters that allow you to control compression and memory consumption.  
You can find detailed information about that parameters in the method's documentation.

### Creating Archives
To create a new `Archive`, pass in a non-existing file URL and `AccessMode.create`.

```swift
let currentWorkingPath = fileManager.currentDirectoryPath
var archiveURL = URL(fileURLWithPath: currentWorkingPath)
archiveURL.appendPathComponent("newArchive.zip")
guard let archive = Archive(url: archiveURL, accessMode: .create) else  {
    return
}
```

### Adding and Removing Entries
You can add or remove entries to/from archives that have been opened with `.create` or `.update` `AccessMode`.
To add an entry from an existing file, you can pass a relative path and a base URL to `addEntry`. The relative path identifies the 
entry within the ZIP archive. The relative path and the base URL must form an absolute file URL that points to the file you want to add to
the archive:

```swift
let fileManager = FileManager()
let currentWorkingPath = fileManager.currentDirectoryPath
var archiveURL = URL(fileURLWithPath: currentWorkingPath)
archiveURL.appendPathComponent("archive.zip")
guard let archive = Archive(url: archiveURL, accessMode: .update) else  {
    return
}
var fileURL = URL(fileURLWithPath: currentWorkingPath)
fileURL.appendPathComponent("file.txt")
do {
    try archive.addEntry(with: fileURL.lastPathComponent, relativeTo: fileURL.deletingLastPathComponent())
} catch {
    print("Adding entry to ZIP archive failed with error:\(error)")
}
```

The `addEntry` method accepts several optional parameters that allow you to control compression, memory consumption and file attributes.  
You can find detailed information about that parameters in the method's documentation.

To remove an entry, you need a reference to an entry within an archive that you can pass to `removeEntry`:

```swift
guard let entry = archive["file.txt"] else {
    return
}
do {
    try archive.remove(entry)
} catch {
    print("Removing entry from ZIP archive failed with error:\(error)")
}
```

### Closure based Reading and Writing
ZIP Foundation also allows you to consume ZIP entry contents without writing them to the file system. 
The `extract` method accepts a closure of type `Consumer`. This closure is called during extraction until the contents of an entry are exhausted:  

```swift
try archive.extract(entry, consumer: { (data) in
    print(data.count)
})
```   
The `data` passed into the closure contains chunks of the current entry. You can control the chunk size of the entry by providing the optional `bufferSize` parameter.

You can also add entries from an in-memory data source. To do this you have to provide a closure of type `Provider` to the `addEntry` method:

```swift
try archive.addEntry(with: "fromMemory.txt", type: .file, uncompressedSize: 4, provider: { (position, size) -> Data in
    guard let data = "abcd".data(using: .utf8) else {
        throw DataProviderError.invalidEncoding
    }
    return data
})
```
The closure is called until enough data has been provided to create an entry of `uncompressedSize`. The closure receives `position` and `size` arguments 
so that you can manage the state of your data source.

### Progress Tracking and Cancellation
All `Archive` operations take an optional `progress` parameter. By passing in an instance of [Progress](https://developer.apple.com/documentation/foundation/progress), you indicate that
you want to track the progress of the current ZIP operation. ZIP Foundation automatically configures the `totalUnitCount` of the `progress` object and continuously updates its `completedUnitCount`.  
To get notifications about the completed work of the current operation, you can attach a Key-Value Observer to the `fractionCompleted` property of your `progress` object.  
The ZIP Foundation `FileManager` extension methods also accept optional `progress` parameters. `zipItem` and `unzipItem` both automatically create a hierarchy of progress objects that reflect the progress of all items contained in a directory or an archive that contains multiple items.  

The [cancel()](https://developer.apple.com/documentation/foundation/progress/1413832-cancel) method of `Progress` can be used to terminate an unfinished ZIP operation. In case of cancelation, the current operation throws an `ArchiveError.cancelledOperation` exception. 

## Credits

ZIP Foundation is written and maintained by [Thomas Zoechling](http://thomas.zoechling.me).  
Twitter: [@weichsel](https://twitter.com/weichsel).


## License

ZIP Foundation is released under the MIT License.  
See [LICENSE](https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE) for details.
