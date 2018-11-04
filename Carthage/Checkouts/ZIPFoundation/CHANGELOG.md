# Changelog

## [0.9.6](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.6)

### Added
 - Swift 4.1 support
 
### Updated
 - Fixed default directory permissions
 - Fixed a compile issue when targeting Linux

## [0.9.5](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.5)

### Added
 - Progress tracking support
 - Operation cancellation support
 
### Updated
 - Improved performance of CRC32 calculations
 - Improved Linux support
 - Fixed wrong behaviour when using the `shouldKeepParent` flag
 - Fixed a linker error during archive builds when integrating via Carthage

## [0.9.4](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.4)

### Updated
 - Fixed a wrong setting for `FRAMEWORK_SEARCH_PATHS` that interfered with code signing
 - Added a proper value for `CURRENT_PROJECT_VERSION` to make the framework App Store compliant when using Carthage

## [0.9.3](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.3)

### Added
 - Carthage support
 
### Updated
 - Improved error handling
 - Made consistent use of Swift's `CocoaError` instead of `NSError`

## [0.9.2](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.2)

### Updated
 - Changed default POSIX permissions when file attributes are missing
 - Improved docs
 - Fixed a compiler warning when compiling with the latest Xcode 9 beta

## [0.9.1](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.1)

### Added
 - Optional parameter to skip CRC32 checksum calculation
 
### Updated
 - Tweaked POSIX buffer sizes to improve IO and comrpression performance
 - Improved source readability
 - Refined documentation
 
### Removed
 - Optional parameter skip decompression during entry retrieval
 
## [0.9.0](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.0)

### Added
 - Initial release of ZIP Foundation.