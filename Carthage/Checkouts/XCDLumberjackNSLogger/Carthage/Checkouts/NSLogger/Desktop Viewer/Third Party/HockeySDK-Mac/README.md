## Version 2.1.0

- [Changelog](http://www.hockeyapp.net/help/sdk/mac/2.1.0/docs/docs/Changelog.html)


## Introduction

HockeySDK-Mac implements support for using HockeyApp in your Mac applications.

The following feature is currently supported:

1. **Collect crash reports:** If you app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp. This works for both beta and live apps, i.e. those submitted to the App Store!

2. **Add analytics to Sparkle:** If you are using Sparkle to provide app-updates (HockeyApp also supports Sparkle feeds for beta distribution) the SDK contains helpers to add some analytics data to each Sparkle request. 


The main SDK class is `BITHockeyManager`. It initializes all modules and provides access to them, so they can be further adjusted if required. Additionally all modules provide their own protocols.

## Prerequisites

1. Before you integrate HockeySDK into your own app, you should add the app to HockeyApp if you haven't already. Read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-create-a-new-app) on how to do it.
2. We also assume that you already have a project in Xcode and that this project is opened in Xcode 4.
3. The SDK supports Mac OS X 10.6.0 or newer.


## Installation & Setup

- [Installation & Setup](http://www.hockeyapp.net/help/sdk/mac/2.1.0/docs/docs/Guide-Installation-Setup.html)
- [Mac Desktop Uploader](http://support.hockeyapp.net/kb/how-tos/how-to-upload-to-hockeyapp-on-a-mac)


## Xcode Documentation

This documentation provides integrated help in Xcode for all public APIs and a set of additional tutorials and HowTos.

1. Download the [HockeySDK-Mac documentation](http://hockeyapp.net/releases/).

2. Unzip the file. A new folder `HockeySDK-Mac-documentation` is created.

3. Copy the content into ~`/Library/Developer/Shared/Documentation/DocSets`

The documentation is also available via the following URL: [http://hockeyapp.net/help/sdk/mac/2.1.0/](http://hockeyapp.net/help/sdk/mac/2.1.0/)

