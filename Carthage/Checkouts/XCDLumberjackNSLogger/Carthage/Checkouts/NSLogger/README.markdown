# NSLogger #
![Icon](https://github.com/fpillet/NSLogger/raw/master/Screenshots/icon_small.png "Icon")

*NSLogger* is a high perfomance logging utility which displays traces emitted by client applications running on **Mac OS X**, **iOS** and **Android**. It replaces traditional console logging (*NSLog()*, Java *Log*) traces and provides powerful additions like display filtering, image and binary logging, traces buffering, timing information, etc.

*NSLogger* feature summary:

  * View logs using the Mac OS X desktop viewer, accept connections from local network clients (using Bonjour) or remote clients connecting directly over the internet
  * Online (application running and connected to _NSLogger_) and offline (saved logs) log viewing
  * Buffer all traces in memory or in a file, send them over to viewer when a connection is acquired
  * Secure logging (connections use SSL by default)
  * Advanced log filtering options
  * Save viewer logs to share them and/or review them later
  * Export logs to text files
  * Open raw buffered traces files that you brought back from client applications not directly connected to the log viewer

**You'll find instructions for use in the [NSLogger wiki](https://github.com/fpillet/NSLogger/wiki).**

Your application emits traces using the *NSLogger* [trace APIs](https://github.com/fpillet/NSLogger/wiki/NSLogger-API). The desktop viewer application (running on **Mac OS X 10.6 or later**) displays them.

Clients automatically find the logger application running on Mac OS X via Bonjour networking, and can optionally connect to a specific remote host/port. You have no setup to do: just start the logger on your Mac, launch your iOS or Mac OS X application then when your app emits traces, they will automatically show up in *NSLogger* if the viewer is running locally on your network. Until a logger is found, logs are buffered on the client so you don't lose anything.

![Desktop Viewer (main window)](https://github.com/fpillet/NSLogger/raw/master/Screenshots/mainwindow.png "Desktop Viewer")

# CocoaPods Install #
[CocoaPods](https://cocoapods.org/) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like AFNetworking in your projects.

## Podfile ##
If your project is configured to use [CocoaPods](https://cocoapods.org/), just add this line to your Podfile:

```ruby
pod "NSLogger"
```

If you are using frameworks or libraries that may use NSLogger, then you can use the NoStrip variant which forces the linker to keep all NSLogger functions in the final build, even those that your code doesn't use. Since linked in frameworks may dynamically check for the presence of NSLogger functions, this is required as the linker wouldn't see this use.

```ruby
pod "NSLogger/NoStrip"
```

# Carthage #
NSLogger is Carthage-compatible. To use it, add the following line to your `Cartfile`:

```
github "fpillet/NSLogger"
```

Then run:

```shell
$ carthage update
```

## Desktop Viewer ##
Download the pre-built, signed version of the [NSLogger desktop viewer](https://github.com/fpillet/NSLogger/releases) for OS X.

## Adding logs to you app ##
A one stop-shopper header file is `<NSLogger/NSLogger.h>`. By importing this header file, you'll be able to add traces to your code this way:

```objective-c
LoggerApp(1, @"Hello world! Today is: %@", [self myDate]);
```

## Starting the logger ##
The `NSLogger.h` will also allow you to start the logger at the begining of your code. To do so, just add the following line to your `main.m` file, at the beginning of your `main()` function:

```objc
LoggerStart(LoggerGetDefaultLogger());
```

In the Preferences of the NSLogger.app desktop viewer, go to the "Network" tab. Type your user name (i.e. $USER) in the "Bonjour service name" text field. This will allow the traces to be received only by the computer of the user who compiled the app (important for team work).

This only work when NSLogger has been added to your project using CocoaPods.

# Project setup #
When using NSLogger without CocoaPods, add `LoggerClient.h`, `LoggerClient.m` and `LoggerCommon.h` (as well as add the `CFNetwork.framework` and `SystemConfiguration.framework` frameworks) to your iOS or Mac OS X application, then replace your *NSLog()* calls with *LogMessageCompat()* calls. We recommend using a macro, so you can turn off logs when building the distribution version of your application.

# Using the desktop logger #
Start the NSLogger application on Mac OS X. Your client app must run on a device that is on the same network as your Mac. When it starts logging traces, it will automatically (by default) look for the desktop NSLogger using Bonjour. As soon as traces start coming, a new window will open on your Mac. Advanced users can setup a Remote Host / Port to log from a client to a specific host).

You can create custom filters to quickly switch between different views of your logs.

# Evolved logging facility #
It's very easy to log binary data or images using *NSLogger*. Use the *LogData()* and *LogImage()* calls in your application, and you're done. Advanced users can also enable remote logging to have logs sent directly from remote devices running at distant locations, or have logs be directed to a file that can later be sent to a remote server.

# Powerful desktop viewer #
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

![Filter Editor](https://github.com/fpillet/NSLogger/raw/master/Screenshots/filtereditor.png "Filter Editor")

# High performance, low overhead #
*NSLogger* runs in its own thread in your application. It tries hard to consume as few CPU and memory as possible. If the desktop viewer has not been found yet, your traces can be buffered in memory until a connection is acquired. This allows for tracing in difficult situations, for example device wakeup times when the network connection is not up and running.

# Advanced colors configuration #
Apply colors to tags and messages using regular expressions.

![Advanced Colors Preferences](https://github.com/djromero/NSLogger/raw/master/Screenshots/advanced_colors_prefs.png "Advanced Colors Preferences")

# Work in progress - Current status #
This tool comes from a personal need for a more powerful logger. There are more features planned for inclusion, here is a quick list of what I'm thinking of. Requests and suggestions are welcome.

 * Search and search term highlight in Details window
 * Rewrite of the desktop viewer
 * Support time-based filtering (filter clause based on the time lapse between a previous trace)
 * Pause (buffer logs) and resume sending logs to the logger, in order to eliminate NSLogger's network load from the equation when testing networking code

You'll find documentation in the [NSLogger Wiki](https://github.com/fpillet/NSLogger/wiki/)

NSLogger uses parts of [Brandon Walkin's BWToolkit](http://www.brandonwalkin.com/bwtoolkit/), for which source code is included with NSLogger.

NSLogger is Copyright (c) 2010-2014 Florent Pillet, All Rights Reserved, All Wrongs Revenged. Released under the [New BSD Licence](http://opensource.org/licenses/bsd-license.php).
The NSLogger icon is Copyright (c) [Louis Harboe](http://harboe.me/)
