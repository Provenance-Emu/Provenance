## Version 5.1.0

This release contains improvements and fixes that were ported from out iOS SDK.

- [IMPROVEMENT] Support tracking events in the background. [#35](https://github.com/bitstadium/HockeySDK-tvOS/pull/35)
- [FIX] Improvements around thread-safety and concurrency for Metrics.[#35](https://github.com/bitstadium/HockeySDK-tvOS/pull/35)
- [FIX] Fix runtime warnings of Xcode 9's main thread checker tool. [#36](https://github.com/bitstadium/HockeySDK-tvOS/pull/36) [#37]([#36](https://github.com/bitstadium/HockeySDK-tvOS/pull/36))

## Version 5.0.0

- [IMPROVEMENT] Metrics can be enabled after it was disabled without relaunching the app. [#28](https://github.com/bitstadium/HockeySDK-tvOS/pull/28)
- [BUGFIX] Fix an issue with `BITAuthenticator`. [#27](https://github.com/bitstadium/HockeySDK-tvOS/pull/27)

## Version 5.0.0-beta.1

This version contains one major breaking change. HockeySDK-tvOS now requires tvOS 10.0 or up.

- [IMPROVEMENT] The SDK now uses the same structure for the "fat framework" as the iOS SDK.

## Version 4.1.2

- [IMPROVEMENT] The SDK documentation is now generated using jazzy.
- [IMPROVEMENT] The SDK can be compiled using Xcode 9 beta 3.
- [IMPROVEMENT] Events are now sent when the app goes into background. This behavior is now consistent across all native SDKs for HockeyApp.
- [BUGFIX] Remove references to store updates from `BITHockeyManager.h`. This caused issues when integrating the SDK using Xcode 9 beta 3. 

## Version 4.1.1

- [BUGFIX] Add a check for `nil` in BITChannel.

## Version 4.1.0

- [NEW] Add ability to track custom events
- [NEW] Additional API to track an event with properties and measurements.
- [BUGFIX] Add Bitcode marker back to simulator slices. This is necessary because otherwise `lipo` apparently strips the Bitcode sections from the merged library completely. As a side effect, this unfortunately breaks compatibility with Xcode 6. [#310](https://github.com/bitstadium/HockeySDK-iOS/pull/310)
- Minor fixes and refactorings

## Version 4.1.0-beta.1

- [IMPROVEMENT] Prevent User Metrics from being sent if `BITMetricsManager` has been disabled.

## Version 4.0.0

- [IMPROVEMENT] Prefix GZIP category on NSData to prevent symbol collisions
- [BUGFIX] Exclude GZIP functionality from none metrics builds

## Version 1.2.0-alpha.1

- [NEW] Add ability to track custom events
- [BUGFIX] Server URL is now properly customizable
- [BUGFIX] Fix memory leak in networking code
- [BUGFIX] Fix different bugs in the events sending pipeline
- [IMPROVEMENT] Events are always persisted, even if the app crashes
- [IMPROVEMENT] Allow disabling `BITMetricsManager` at any time
- [IMPROVEMENT] Reuse `NSURLSession` object
- [IMPROVEMENT] Under the hood improvements and cleanup

## Version 1.1.0-beta.1

- [NEW] User Metrics including users and sessions data is now in public beta

## Version 1.1.0-alpha.1

- [NEW] Add User Metrics support
- [UPDATE] Add improvements and fixes from 1.0.0-beta.2

## Version 1.0.0-beta.2

- [FIX] Add userPath anonymization
- [FIX] Remove unnecessary calls to -[NSUserDefaults synchronize]
- [FIX] Fix NSURLSession memory leak
- [FIX] Minor refactorings & bug fixes

## Version 1.0.0-beta.1

- [NEW] Added support for beta update notifications
- [NEW] Added support for authentication

## Version 1.0.0-alpha.1

- [NEW] `BITCrashManager`: Added tvOS support
