# UnrarKit CHANGELOG

## 2.11

* Fixed a header name conflict with Realm (Issue #90)
* Incorrect passwords in RAR5 archives now produce a specific and helpful error message (PR #101 - Thanks to [@gpotari](https://github.com/gpotari) for the idea and implementation!)
* Updated to v6.1.7 of UnRAR library (PR #103 - Thanks to [@gpotari](https://github.com/gpotari) )


## 2.10

* Added method (`checkDataIntegrityIgnoringCRCMismatches:`) to prompt user for a decision on whether or not to ignore CRC mismatches (Issue #82)
* Fixed crash in `+pathIsARAR:` when a file is unreadable (Issue #85)
* Fixed crash in `-_unrarOpenFile:inMode:withPassword:error:` (PR #97)
* Updated to v5.9.4 of UnRAR library
* Xcode 12 compatibility in Carthage


## 2.9

* Added support for `NSProgress` and `NSProgressReporting` in all extraction and iteration methods (Issue #34)
* Added enhanced support for multivolume archives (PRs #59, #38 - Thanks to [@aonez](https://github.com/aonez) for the idea and implementation!)
* Added methods for checking data integrity of archived files (Issue #26, PR #61 - Thanks to [@amosavian](https://github.com/amosavian) for the suggestion!)
* Added new method `-iterateFileInfo:error:` that takes a block, allowing for lazy iteration of file info, without building up an in-memory array (Issue #73 - Thanks to [@yanex](https://github.com/yanex) for the suggestion!)
* Added detailed logging using new unified logging framework. See [the readme](README.md) for more details (Issue #35)
* Added localized details to returned `NSError` objects (Issue #45)
* Fixed bug when listing file info for multivolume archive that resulted in duplicate items (Issue #67 - Thanks to [@skito](https://github.com/skito) for catching this)
* Moved `unrar` sources into a static library, and addressed a wide variety of warnings exposed by the `-Weverything` flag (Issue #56)
* Upgraded UnRAR library to v5.6.3 (Issue #77)
* Switched to Travis Build Stages instead of the unofficial Travis-After-All (Issue #42)
* Added CocoaPods Test Spec, so your test suite can also run UnrarKit's unit tests Issue #44
* Fixed warnings from Xcode 9 (Issue #51)
* Removed iOS-specific targets, after allowing macOS framework and unit test bundles to be cross-platform (Issue #55)


## 2.8.1

Updated to UnRAR library v 5.5.5 (Issue #43 - Thanks to [@Jegge](https://github.com/Jegge) for the suggestion!)

## 2.8

* Add fields for total compressed and uncompressed sizes of archive (Issue #32 - Thanks to @gerchicov-bp for the suggestion!)
* Upgraded to UnRAR library v5.4.5 (PR #36 - Thanks to @aonez for the suggestion!)
* Began importing `Foundation` instead of `UIKit` or `Cocoa` in `UnrarKit.h` (PR #37 - Thanks to @amosavian for the suggestion!)

## 2.7.1

* Pushing tagged builds to CocoaPods from Travis
* Adding release notes to GitHub

## 2.7

Updated to the latest version of the UnRAR library (v5.3.11)


## 2.6

* Added full support for Carthage (Issue #22)
* Added annotations for nullability, improving compatibility with Xcode 7 and Swift


## 2.5.3

Fixed Podspec bug causing build errors when building as a framework with CocoaPods (Issue #28)


## 2.5.2

Moved off of deprecated `xcconfig` attribute in podspec (Issue #25)


## 2.5.1

Improved performance of the `-isPasswordProtected` method (Issue #24)


## 2.5

Fixed bug in -extractFilesTo:overwrite:progress:error: that would sometimes cause garbage characters in the extracted files' names (Issue #20)


## 2.4.3

Tweaked isPasswordProtected so it doesn't log an error message when an archive has a header password (Issue #21)


## 2.4.2

Fixed bug causing validatePassword to return NO for valid passwords in RAR5 archives (Issue #19)


## 2.4.1

Decreased size of library, by removing large sample archives (Issue #18), and added more information to the readme file


## 2.4

Added methods to detect whether a file is a RAR archive (Issue #17)


## 2.3

* Full Unicode support (Issue #11)
* Better support for moving files during a decompression into memory by adding a new block-based method that streams the file (Issue #4)
* Added pervasive use of new [URKFileInfo](Classes/URKFileInfo.h) class, which exposes several metadata fields of each file, rather than relying on passing filenames around (Issue #7 - Thanks, @mmcdole!)
* Added methods to test whether an archive is password-protected, and to test a given password (Issue #10 - Thanks, @scinfu!)
* Added progress reporting callbacks to most methods (Issue #6)
* Added several block-based methods that allow a guarantee of completing successfully, even if a file moves or gets deleted (Issue #5)
* Now fully thread-safe, even accessing the same archive object on different threads (it will block, instead of crashing)


## 2.2.4

Added -lc++ to CocoaPods linker flags, so that a .mm file is no longer required for a successful build


## 2.2.2

Added documentation, full Travis CI integration


## 2.2

Upgraded to unrar library 5.2.1


## 2.1

Fixed bug in NSErrors generated


## 2.0.7

Fixed major leak of file descriptors, causing clients to run out of file descriptors


## 2.0.6

Added requires_arc flag to podspec


## 2.0.5

Fixed an Xcode 6 compilation bug


## 2.0.2

First release in CocoaPods spec repo


## 2.0.0

Initial release
