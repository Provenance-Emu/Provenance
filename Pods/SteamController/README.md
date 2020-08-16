# SteamController

Drop-in support for Steam Controllers for iOS and tvOS.

For information about how to use a Steam Controller in Bluetoth LE mode, see [Steam Controller BLE](https://support.steampowered.com/kb_article.php?ref=7728-QESJ-4420#switch).

## Example

To run the example project, clone the repo, and run the SteamControllerTestApp target.

![Screenshot](screenshot.png)

In the example app, power on your controller (in BLE or BLE pairing mode) and press Scan. Connected controllers will appear in the list, and the UI will reflect the state of the controller. Tapping on a controller from the list will open the settings view for that controller, where you can also see the battery level, and change its configuration (seen above).

## Requirements

- iOS 12 or later (not tested on earlier versions).
- Steam Controller with [BLE firmware](https://support.steampowered.com/kb_article.php?ref=7728-QESJ-4420#switch).
- A game supporting MFi controllers using the `GameController` framework.
- Starting on iOS 13, your app's Info.plist needs a `NSBluetoothAlwaysUsageDescription` key with a description of how it uses bluetooth.

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```
To integrate SteamController into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'SteamController'
```

Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate SteamController into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "zydeco/SteamController"
```

Run `carthage update` to build the framework and drag the built `SteamController.framework` into your Xcode project.

## Usage

Everything should work like with MFi controllers. Depending on how your game works, you might not need any changes at all.

- `#import <SteamController/SteamController.h>`.
- To listen for steam controllers, either:
  - Call `[SteamControllerManager listenForConnections]` when your app starts (uses private IOKit API).
  - Call `[[SteamControllerManager sharedManager] scanForControllers]` when you want to scan for controllers.
- The framework will post `GCControllerDidConnectNotification` and `GCControllerDidDisconnectNotification`, as with native controllers.
- Connected Steam Controllers will be returned in `[GCController controllers]`.
- Steam Controllers are a subclass of `GCController` (`SteamController`) that implements the `extendedGamepad` profile.
- Core buttons are mapped to Apple's MFi Extended Gamepad Profile.
- Trackpads and stick can be mapped to D-pad and thumbsticks. (see below)
- Trackpads can be set to require click for input (default), or not.

#### Button Mapping
- Analog Stick: L-Thumbstick
- Left Trackpad: D-Pad *(Requires Click)*
- Right Trackpad: R-Thumbstick / C-Buttons *(Requires Click)*
- A, B, X, Y: Equivalent
- Bumpers/Shoulders: L1 / R1
- Triggers: L2 / R2
- Grip buttons: L3 / R3
- Steam Button: Pause handler and combinations via `steamButtonCombinationHandler`
- Analog Stick click: L3 *(Default)*
- Trackpad clicks: L3 / R3 (when click is not required for input)
- Back: Options button
- Forward: Menu button

##### Alternate mapping for backward compatibility:
Since options and menu buttons were added in iOS 13, back and forward are also added as a class extension to `GCExtendedGamepad`.
- Back: `steamBackButton`
- Forward: `steamForwardButton`

#### Controller Configuration

The `SteamController` class has some additional properties to customise its configuration.
See the [documentation](https://namedfork.net/SteamController/Classes/SteamController.html) for more info.
These are available as GUI options in the example app.

## License

The SteamController framework is available under the MIT license. See the LICENSE file for more info.
