<p align="center">
  <img src="https://github.com/fpillet/NSLogger/raw/master/Desktop/Resources/Icon/1290083967_Console.png" title="NSLogger" width=128>
</p>

# NSLogger

[![BuddyBuild](https://dashboard.buddybuild.com/api/statusImage?appID=5914439af77e0000015a7b82&branch=master&build=latest)](https://dashboard.buddybuild.com/apps/5914439af77e0000015a7b82/build/latest?branch=master)
[![Pod Version](http://img.shields.io/cocoapods/v/NSLogger.svg?style=flat)](http://cocoadocs.org/docsets/NSLogger/)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Pod Platform](http://img.shields.io/cocoapods/p/NSLogger.svg?style=flat)](http://cocoadocs.org/docsets/NSLogger/)
[![Pod License](http://img.shields.io/cocoapods/l/NSLogger.svg?style=flat)](http://opensource.org/licenses/BSD-3-Clause)
[![Reference Status](https://www.versioneye.com/objective-c/nslogger/reference_badge.svg?style=flat)](https://www.versioneye.com/objective-c/nslogger/references)

**NSLogger** is a high performance logging utility which displays traces emitted by client applications running on *macOS*, *iOS* and *Android*. It replaces traditional console logging traces (*NSLog()*, Java *Log*).

The **NSLogger Viewer** runs on macOS and replaces *Xcode*, *Android Studio* or *Eclipse* consoles. It provides powerful additions like display filtering, defining log domain and level, image and binary logging, message coloring, traces buffering, timing information, link with source code, etc.

<p align="center">
  <img src="https://github.com/MonsieurDart/NSLogger/raw/swiftiosclient/Screenshots/mainwindow.png" title="Desktop Viewer (main window)">
</p>

**NSLogger** feature summary:

* View logs using the desktop application
* Logs can be sent from device or simulator
* Accept connections from local network clients (using *Bonjour*) or remote clients connecting directly over the internet
* Online (application running and connected to *NSLogger*) and offline (saved logs) log viewing
* Buffer all traces in memory or in a file, send them over to viewer when a connection is acquired
* Define a log domain (app, view, model, controller, network…) and an importance level (error, warning, debug, noise…)
* Color the log messages using regexp
* Log images or raw binary data
* Secure logging (connections use SSL by default)
* Advanced log filtering options
* Save viewer logs to share them and/or review them later
* Export logs to text files
* Open raw buffered traces files that you brought back from client applications not directly connected to the log viewer

Here is what it looks like in action:

<p align="center">
  <img src="https://github.com/MonsieurDart/NSLogger/raw/swiftiosclient/Screenshots/demo_video.gif" title="Viewer Demo">
</p>



# Basic Usage

Without any change to your code, all the `NSLog()` logs from your application are redirected to the NSLogger desktop viewer. The viewer is found automatically on your network, using Bonjour.

A rich API lets you log messages, binary data or images with a lot of detail. Simple wrappers are available for your convenience:

**Swift** wrapper API:

```swift
import NSLogger

[…]

// logging some messages
Log(.Network, .Info, "Checking paper level…")

// logging image
Log(.View, .Noise, myPrettyImage)

// logging data
Log(.Custom("My Domain"), .Noise, someDataObject)

```

**Objective-C** wrapper API:

```objective-c
#import <NSLogger/NSLogger.h>

[…]

LoggerApp(1, @"Hello world! Today is: %@", [self myDate]);
LoggerNetwork(1, @"Hello world! Today is: %@", [self myDate]);
```



# Installation

- **Step 1.** Download the *NSLogger desktop app* on your Mac.
- **Step 2.** Add the *NSLogger framework* to your project.
- **Step 3.** There is no step 3…

## Desktop Viewer Download

Download the pre-built, signed version of the [NSLogger desktop viewer](https://github.com/fpillet/NSLogger/releases) for macOS. Don't forget to launch the application on your Mac. It won't show a window until a client connects to it and starts logging.

## Client Framework Install

### CocoaPods Install

If your project is configured to use [CocoaPods](https://cocoapods.org/), just add this line to your `Podfile`:

```ruby
pod "NSLogger"
```

The above only includes C and Obj-C APIs and is suitable for use in applications without any Swift code.
Swift syntactic sugar APIs are added with the `Swift` subspec. If you're developing code in Swift or a mixed Swift / Obj-C environment, use:

```ruby
pod "NSLogger/Swift"
```

Note that you don't strictly need to include the `/Swift` variant for your Swift applications. You can perfectly develop your own extensions that call into NSLogger's C APIs without using the basic provided ones.

Finally if you are using frameworks or libraries that may use NSLogger, then you can use the `NoStrip` variant which forces the linker to keep all NSLogger functions in the final build, even those that your code doesn't use. Since linked in frameworks may dynamically check for the presence of NSLogger functions, this is required as the linker wouldn't see this use.

```ruby
pod "NSLogger/NoStrip"
```

### Carthage Install

NSLogger is Carthage-compatible. It builds two frameworks: `NSLogger` and `NSLoggerSwift`. You'll need to pick either one (but not both) to use in your application. Both can be used with Swift, the `NSLoggerSwift` variant adds a simple Swift layer to make NSLogger easier to use from Swift code. You can perfectly develop your own extensions that call into NSLogger's C APIs without using the basic provided ones, and just use the `NSLogger` framework.

Depending on the framework you choose, your code will need to `import NSLogger` or `import NSLoggerSwift`. This is a difference with Cocoapods support where you always `import NSLogger`.

```
github "fpillet/NSLogger"
```

**or**

```
github "fpillet/NSLoggerSwift"
```


Then run:

```shell
$ carthage update
```

Again, the `NSLogger.xcodeproj` top-level project offers two targets (`NSLogger` and `NSLoggerSwift`). Add the built framework that suits your needs.

# Advanced Usage

## Using NSLogger on a Shared Network

The first log sent by NSLogger will start the logger, by default on the first *Bonjour* service encountered. But when multiple NSLogger users share the same network, logger connections can get mixed.

To avoid confusion between users, just add this when you app starts (for example, in the `applicationDidFinishLaunching` method:

```objc
LoggerSetupBonjourForBuildUser();
```

Then, in the *Preferences* pane of the NSLogger.app desktop viewer, go to the `Network` tab. Type your user name (i.e. `$USER`) in the "*Bonjour service name*" text field.

This will allow the traces to be received only by the computer of the user who compiled the app.

*This only work when NSLogger has been added to your project using CocoaPods*.

## Manual Framework Install

When using NSLogger without CocoaPods, add `LoggerClient.h`, `LoggerClient.m` and `LoggerCommon.h` (as well as add the `CFNetwork.framework` and `SystemConfiguration.framework` frameworks) to your iOS or Mac OS X application, then replace your *NSLog()* calls with *LogMessageCompat()* calls. We recommend using a macro, so you can turn off logs when building the distribution version of your application.

## How Does the Connection Work?

For automatic discovery of the desktop viewer, your application must run on a device that is on the same network as your Mac. When your app starts logging, the NSLogger framework automatically (by default) looks for the desktop viewer using *Bonjour*. As soon as traces start coming, a new window will open on your Mac.

Advanced users can setup a Remote Host / Port to log from a client to a specific host), or specify a Bonjour name in case there are multiple viewers on the network.

## Advanced Desktop Viewer Features

The desktop viewer application provides tools like:

* Filters (with [regular expression matching](https://github.com/fpillet/NSLogger/wiki/Tips-and-tricks)) that let your perform data mining in your logs
* Timing information: each message displays the time elapsed since the previous message in the filtered display, so you can get a sense of time between events in your application.
* Image and binary data display directly in the log window
* [Markers](https://github.com/fpillet/NSLogger/wiki/Tips-and-tricks) (when a client is connected, place a marker at the end of a log to clearly see what happens afterwards, for example place a marker before pressing a button in your application)
* Fast navigation in your logs
* Display and export all your logs as text
* Optional display of file, line and function for uncluttered display

Your logs can be saved to a `.nsloggerdata` file, and reloaded later. When logging to a file, name your log file with extension `.rawnsloggerdata` so NSLogger can reopen and process it. You can have clients remotely generating raw logger data files, then send them to you so you can investigate post-mortem.

Note that the NSLogger Mac OS X viewer requires **Mac OS X 10.6 or later**.

<p align="center">
  <img src="https://github.com/fpillet/NSLogger/raw/master/Screenshots/filtereditor.png" title="Filter Editor">
</p>

## Advanced Colors Configuration

Apply colors to tags and messages using regular expressions.

<p align="center">
  <img src="https://github.com/fpillet/NSLogger/raw/master/Screenshots/advanced_colors_prefs.png" title="Advanced Colors Preferences">
</p>

To define the color, you can use:
- A standard NSColor name, for example: `blue`
- Hex colors, for example: `#DEAD88`
- You can add the prefix `bold`, for example: `bold red`

## High Performance, Low Overhead

The *NSLogger* framework runs in its own thread in your application. It tries hard to consume as few CPU and memory as possible. If the desktop viewer has not been found yet, your traces can be buffered in memory until a connection is acquired. This allows for tracing in difficult situations, for example device wakeup times when the network connection is not up and running.


# Credits

NSLogger is Copyright (c) 2010-2018 Florent Pillet, All Rights Reserved, All Wrongs Revenged. Released under the [New BSD Licence](http://opensource.org/licenses/bsd-license.php). NSLogger uses parts of [Brandon Walkin's BWToolkit](http://www.brandonwalkin.com/bwtoolkit/), for which source code is included with the NSLogger viewer application. The NSLogger icon is Copyright (c) [Louis Harboe](http://harboe.me/)
