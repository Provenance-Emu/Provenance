[![Language](https://img.shields.io/badge/Language-Swift%203.2%20%7C%20Obj%20C-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![Platforms OS X | iOS | watchOS | tvOS](https://img.shields.io/badge/Platforms-OS%20X%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-lightgray.svg?style=flat)](https://developer.apple.com/swift/)
[![License MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](https://github.com/robreuss/VirtualGameController/blob/master/LICENSE)
[![Carthage](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-4BC51D.svg?style=flat)](https://cocoapods.org/?q=virtualgamecontroller)
![Travis](https://travis-ci.org/robreuss/VirtualGameController.svg)

![Logo](http://robreuss.squarespace.com/storage/Game-Controller-Outline-300px.png)
# Virtual Game Controller

## Overview
Virtual Game Controller (VGC) makes it simple to create software-based controllers for games and other purposes, enabling you to easily control one iOS device with another (or multiple other devices, such as in the case of a tvOS game).  The framework wraps Apple's GCController Framework API, making it easy to simulatenously support both your own software-based controllers and hardware-based controllers that conform to the MFi standard, with a single code base.  The [GCController API](https://developer.apple.com/library/content/documentation/ServicesDiscovery/Conceptual/GameControllerPG/Introduction/Introduction.html#//apple_ref/doc/uid/TP40013276-CH1-SW1) supports both reading the values of game controller elements directly (polling) as well as registering to be called when a value changes using a block-based handler.  VGC operates the same way and supports all of the features of the GCController API for both software- and hardware-based controllers.  

While VGC is typically used to have an iOS device act as a controller for another iOS or tvOS device, it can also be used where two iOS devices act as peers, with a shared game environment presented on each device.  In that type of implementation, user inputs through on-screen controls flow through the framework and are processed by the handlers on both devices.  VGC supports easy creation of custom element types, including images and Data types, so that game logic such as state can be coordinated between the two devices.  This capability is perfect for table-top games with two players, including ARKit games where you want both players to see and act on a common game space.  

The framework comes with a rich set of sample apps for iOS, tvOS, and MacOS, including both SceneKit and SprikeKit examples.

## Features

- **Wraps Apple's *GameController* framework API (GCController)**
- **Create software-based controllers**
- **High performance**
- **<5ms latency (including processing) when sending Doubles (64-bit words) at 60/sec**
- **Both closures and polling supported for processing input**
- **Support for peer mode**
- **Controller forwarding**
- **Simple bidirectional communication on a shared channel**
- **Device motion support**
- **Custom elements**
- **Custom element mapping**
- **WiFi-based**
- **Ability to enhance inexpensive slide-on/form-fitting controllers**
- **iCade controller support** 
- **Support for snapshots compatible with GCController snapshots** 
- **Framework-based, no dependencies**

## Requirements 

- iOS 9.0+ / MacOS 10.9+
- Xcode 9 / Swift 3.2 & 4.0 / Objective C

## Platform Support

- iOS
- tvOS
- MacOS
- watchOS

## Some Use Cases
**VirtualGameController** is a drop-in replacement for Apple's _Game Controller_ framework, so it can be easily integrated into existing controller-based games.

**VirtualGameController** may be useful in the following cases:

- **Developing and supporting software-based controllers.**  Enable your users to use their iPhone, iPad or Apple Watch to control your game, leveraging 3d touch and motion input.  Especially useful with Apple TV.  Inputs are flowed through the GCController API (that is, through the MFi profiles) and so your software-based controller will appear as a hardware-based controller.  Easily send information from your game to your software controller (bidirectional communication).  The API for creating a software-based controller is simple and easy-to-use.
- **Providing a pair of users with a shared gaming experience (ARKit).** VGC makes it easy to implement a shared controller environment, so that a pair of users playing the same game on their respective devices will receive controller input data from both devices (users).  A single set of block-based handlers can be implemented to handle input from both on-screen controls and controller data received from the opposite device.  VGC also makes it easy to manage state across the devices by using custom elements.
- **Creating a hybrid hardware/software controller using controller forwarding.**
- **Supporting large numbers of controllers for social games.**  There are no imposed limits on the number of hardware or software controllers that can be used with a game.  The two third-party controller limit on the Apple TV can be exceeded using controller forwarding (bridging), hybrid controllers and software-based controllers. 
- **Creating text-driven games.**  Support for string-based custom inputs makes it easy to create text-oriented games.  Use of voice dictation is demonstrated in the sample projects.

## Terminology
* **Peripheral**: A software-based game controller.
* **Central**: Typically a game that supports hardware and software controllers.  The Central utilizes VirtualGameController as a replacement for the Apple Game Controller framework.
* **Bridge**: Acts as a relay between a Peripheral and a Central, and represents a hybrid of the two.  Key use case is "controller forwarding".

## Framework Integration
Platform-specific framework projects are included in the workspace.  A single framework file supports both Peripherals (software-based controllers) and Centrals (that is, your game).

``` swift
import VirtualGameController
```

Note that you currently need to ````import GameController```` as well.

See the [instructions on the Wiki](https://github.com/robreuss/VirtualGameController/wiki/Implementing-in-Objective-C) for utilizing Objective C.
``
#### CocoaPods
Preliminary support is in place for [CocoaPods](https://cocoapods.org/?q=virtualgamecontroller).

#### Carthage
In order to integrate using Carthage, add VGC to your Cartfile:

````
github "robreuss/VirtualGameController"
````

Then use platform-specific commands to create the build products that you need to add to your project:

````
carthage update --platform iOS
carthage update --platform OSX
carthage update --platform tvOS
carthage update --platform watchOS
````

## Reference Apps
The project includes a pair apps that implement most of the available framework features and settings, as well as providing a generally helpful test environment.

### Peripheral_iOS ###
The ````Peripheral_iOS```` sample project provides a reference implementation of a software-based game controller.  Once you have implemented VGC in your game (Central) you can use the Peripheral_iOS app to test it:

![Peripheral Test](https://static1.1.sqspcdn.com/static/f/677681/26657435/1446879995410/peripheral.png?token=Tfx6nkrlOJpryXF1LmuZmIvXUTM%3D)

### Central_iOS ###
The ````Central_iOS```` sample project provides a reference implementation of a Central (your game, to which Peripherals connect).  It provides a straightforward way of testing your implementation of Peripherals:

![Central Test](https://static1.1.sqspcdn.com/static/f/677681/26657433/1446879952810/central.png?token=hvc5ml0dydCvhbfVtXjZ39Cai2U%3D)

## Core Documentation
* [Integrating VGC into your Game (Central)](https://github.com/robreuss/VirtualGameController/wiki/Game-Integration-(Central)) 
* [Creating a Software-based Controller (Peripheral)](https://github.com/robreuss/VirtualGameController/wiki/Creating-a-Software-based-Controller-(Peripheral)) 
* [Implementing Peer/Multiplayer Capabilities](https://github.com/robreuss/VirtualGameController/wiki/Implementing-Peer-Multiplayer-Capabilities)

## Further Documentation
* [Sending Messages from Central to Controller](https://github.com/robreuss/VirtualGameController/wiki/Bidirectional-Communication) 
* [Setup a Peripheral From the Central at Runtime](https://github.com/robreuss/VirtualGameController/wiki/Peripheral-Setup-from-the-Central) 
* [Custom Elements](https://github.com/robreuss/VirtualGameController/wiki/Custom-Elements)
* [Custom Mappings](https://github.com/robreuss/VirtualGameController/wiki/Custom-Mappings)
* [Using Objective C](https://github.com/robreuss/VirtualGameController/wiki/Implementing-in-Objective-C)
* [Apple Watch Integration](https://github.com/robreuss/VirtualGameController/wiki/Apple-Watch-Integration)
* [Supporting iCade Controllers](https://github.com/robreuss/VirtualGameController/wiki/iCade-Controller-Support)

## Sample Projects
* [Exploring the Sample Projects](https://github.com/robreuss/VirtualGameController/wiki/Exploring-the-Sample-Projects) 
* [Testing Using DemoBots](https://github.com/robreuss/VirtualGameController/wiki/Testing-using-DemoBots) 
* [Testing Using Scenekit Vehicle](https://github.com/robreuss/VirtualGameController/wiki/Testing-using-SceneKitVehicle)
* [Setup Frameworks in Sample Projects](https://github.com/robreuss/VirtualGameController/wiki/Setup-Frameworks-in-Sample-Projects) 
 
## Contact and Support
Feel free to contact me with any questions either using [LinkedIn](https://www.linkedin.com/pub/rob-reuss/2/7b/488) or <virtualgamecontroller@gmail.com>.


## Working with MFi Hardware-based Controllers
VirtualGameController is a wrapper around Apple's Game Controller framework, and so working with hardware controllers with VGC is the same as it is with Apple's [Game Controller framework](https://developer.apple.com/library/tvos/documentation/GameController/Reference/GCController_Ref/index.html).  See the Game Integration section below and the sample projects for additional details.


## License
The MIT License (MIT)

Copyright (c) [2017] [Rob Reuss]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[Logo from here](https://openclipart.org/user-detail/qubodup)


