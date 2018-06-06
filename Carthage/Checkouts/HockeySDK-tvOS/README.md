[![Build Status](https://www.bitrise.io/app/15b9a1dcfda1cf1b/status.svg?token=n9IZGTdsHL_AsoavGsz1kw&branch=develop)](https://www.bitrise.io/app/15b9a1dcfda1cf1b)
[![Version](http://cocoapod-badges.herokuapp.com/v/HockeySDK-tvOS/badge.png)](http://cocoadocs.org/docsets/HockeySDK-tvOS)
[![Slack Status](https://slack.hockeyapp.net/badge.svg)](https://slack.hockeyapp.net)

# HockeySDK-tvOS

## Version 5.1.0

HockeySDK-tvOS implements support for using HockeyApp in your tvOS applications.

The following features are currently supported:

1. **Collect crash reports:** If your app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp. This works for both beta and letive apps, i.e. those submitted to the App Store.

2. **User Metrics:** Understand user behavior to improve your app. Track usage through daily and monthly active users, monitor crash impacted users, as well as customer engagement through session count. You can now track Custom Events in your app, understand user actions and see the aggregates on the HockeyApp portal.

3. **Update notifications:** The app will check with HockeyApp if a new version for your Ad-Hoc or Enterprise build is available. If yes, it will show an alert view with informations to the moste recent version.

4. **Authenticate:** Identify and authenticate users of Ad-Hoc or Enterprise builds.

## 1. Setup
It is super easy to use HockeyApp in your tvOS app. Have a look at our [documentation](https://www.hockeyapp.net/help/sdk/tvos/5.0.0/index.html) and onboard your app within minutes.

<a id="requirements"></a> 
## 1. Requirements

1. We assume that you already have a project in Xcode, and that this project is opened in Xcode 8 or later.
2. The SDK supports tvOS 10.0 and later.

**[NOTE]** 
Be aware that tvOS requires Bitcode.

## 2. Documentation

Please visit [our landing page](https://www.hockeyapp.net/help/sdk/tvos/5.1.0/index.html) as a starting point for all of our documentation.

Please check out our [changelog](http://www.hockeyapp.net/help/sdk/tvos/5.1.0/changelog.html), as well as our [troubleshooting section](https://www.hockeyapp.net/help/sdk/tvos/5.1.0/installation--setup.html#troubleshooting).

## 3. Contributing

We're looking forward to your contributions via pull requests.

### 3.1 Development environment

* A Mac running the latest version of macOS.
* Get the latest Xcode from the Mac App Store.
* [Jazzy](https://github.com/realm/jazzy) to generate documentation.
* [CocoaPods](https://cocoapods.org/) to test integration with CocoaPods.
* [Carthage](https://github.com/Carthage/Carthage) to test integration with Carthage.

### 3.2 Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

### 3.3 Contributor License

You must sign a [Contributor License Agreement](https://cla.microsoft.com/) before submitting your pull request. To complete the Contributor License Agreement (CLA), you will need to submit a request via the [form](https://cla.microsoft.com/) and then electronically sign the CLA when you receive the email containing the link to the document. You need to sign the CLA only once to cover submission to any Microsoft OSS project. 

## 4. Contact

If you have further questions or are running into trouble that cannot be resolved by any of the steps [in our troubleshooting section](https://www.hockeyapp.net/help/sdk/tvos/5.0.0/installation--setup.html#troubleshooting), feel free to open an issue here, contact us at [support@hockeyapp.net](mailto:support@hockeyapp.net) or join our [Slack](https://slack.hockeyapp.net).
