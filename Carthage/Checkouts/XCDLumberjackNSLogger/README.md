## About

[![Platform](https://img.shields.io/cocoapods/p/XCDLumberjackNSLogger.svg?style=flat)](http://cocoadocs.org/docsets/XCDLumberjackNSLogger/)
[![Pod Version](https://img.shields.io/cocoapods/v/XCDLumberjackNSLogger.svg?style=flat)](http://cocoadocs.org/docsets/XCDLumberjackNSLogger/)
[![License](https://img.shields.io/cocoapods/l/XCDLumberjackNSLogger.svg?style=flat)](LICENSE)

**XCDLumberjackNSLogger** is a [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) logger which sends logs to [NSLogger](https://github.com/fpillet/NSLogger).

## Requirements

- Runs on iOS 8.0 and later
- Runs on OS X 10.10 and later
- Runs on tvOS 9.0 and later

## Installation

XCDLumberjackNSLogger is available through CocoaPods and Carthage.

CocoaPods:

```ruby
pod "XCDLumberjackNSLogger", "~> 1.1"
```

Carthage:

```objc
github "0xced/XCDLumberjackNSLogger" ~> 1.1
```

## Usage

XCDLumberjackNSLogger is [fully documented](http://cocoadocs.org/docsets/XCDLumberjackNSLogger/).

#### Binding to User Defaults

The easiest way to use XCDLumberjackNSLogger is to bind a logger to a user defaults key.

```objc
[XCDLumberjackNSLogger bindToBonjourServiceNameUserDefaultsKey:@"NSLoggerBonjourServiceName" configurationHandler:nil];
```

Anytime you change the user defaults key (`NSLoggerBonjourServiceName` in this example), the logger reconnects to the desktop viewer with the given service name.

You can change the service name user defaults manually with

```objc
[[NSUserDefaults standardUserDefaults] setObject:serviceName forKey:@"NSLoggerBonjourServiceName"];
```

or with a [Settings bundle][1]:

```xml
<dict>
	<key>AutocapitalizationType</key>
	<string>None</string>
	<key>AutocorrectionType</key>
	<string>No</string>
	<key>DefaultValue</key>
	<string></string>
	<key>IsSecure</key>
	<false/>
	<key>Key</key>
	<string>NSLoggerBonjourServiceName</string>
	<key>KeyboardType</key>
	<string>Alphabet</string>
	<key>Title</key>
	<string>NSLogger Service Name</string>
	<key>Type</key>
	<string>PSTextFieldSpecifier</string>
</dict>
```

This is very handy to get logs even in the App Store with zero overhead. Just open the settings of your app (in the iOS Settings app) and change the service name to automatically activate the logger.

When debugging with Xcode you can set `-NSLoggerBonjourServiceName "Your Service Name"` in *Arguments Passed On Launch* [in your scheme][2] to set the `NSLoggerBonjourServiceName` user default.

#### Simply send logs to NSLogger

```objc
[DDLog addLogger:[XCDLumberjackNSLogger new]];
```

#### Configuring a bonjour service name

```objc
NSString *bonjourServiceName = [[[NSProcessInfo processInfo] environment] objectForKey:@"NSLOGGER_BONJOUR_SERVICE_NAME"];
[DDLog addLogger:[[XCDLumberjackNSLogger alloc] initWithBonjourServiceName:bonjourServiceName]];
```

#### Translating contexts to tags

```objc
XCDLumberjackNSLogger *logger = [XCDLumberjackNSLogger new];
logger.tags = @{ @80 : @"CocoaHTTPServer", @((NSInteger)0xced70676) : @"XCDYouTubeKit" };
[DDLog addLogger:logger];
```

#### Configuring a viewer host

```objc
XCDLumberjackNSLogger *logger = [XCDLumberjackNSLogger new];
LoggerSetViewerHost(logger.logger, CFSTR("10.0.1.7"), 50000);
[DDLog addLogger:logger];
```

## Contact

Cédric Luthi

- http://github.com/0xced
- http://twitter.com/0xced

## License

XCDLumberjackNSLogger is available under the MIT license. See the [LICENSE](LICENSE) file for more information.

[1]: https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/UserDefaults/Preferences/Preferences.html
[2]: https://developer.apple.com/library/ios/recipes/xcode_help-scheme_editor/Articles/SchemeRun.html
