reicast
===========
reicast is a multi-platform Sega Dreamcast emulator.

This is a developer-oriented resource, if you just want bins head over to http://reicast.com/

For development discussion, join [#reicast in freenode](https://webchat.freenode.net/?channels=reicast)
 or stop by the [reicast Discord server](http://discord.gg/Hc6CF72)

Caution
-------
The source is a mess, and dragons might eat your cat when you clone this project. We're working on cleaning things up, but don't hold your breath. Why don't you lend a hand?

Rebranding/(hard)forks
----------------
If you are interested into further porting/adapting/whatever, *please* don't fork off. I hate that. Really.

Let's try to keep everything under a single project :)

Submitting Issues
----------------
Please take a moment to search the open issues for one similar to yours and add your info to it.  
If you cannot find a similar issue, click the 'New Issue' button and make sure to fill out the form.

*Please Note:*  
Duplicate issues may be closed with a link to the existing issue.  
Bugs that do not include a form may be closed until it is filled out.

Contributing
------------
For small/one-off fixes a PR from a github fork is alright. For longer term collaboration we prefer to use namespaced branches in the form of `<username>/<whatever>` in the main repo. 

Before you work on something major, make sure to check the issue tracker to coordinate with other contributors, and open an issue to get feedback before doing big changes/PRs. It is always polite to check the history of the code you're working on and collaborate with the people that have worked on it. You can introduce yourself in [Meet the team](https://github.com/reicast/reicast-emulator/issues/1113).

Everything goes to master via PRs. Test builds are run automatically for both internal and external PRs, and generally should pass unless there's a really good reason for breakage.  You might want to check our [CLA](https://gist.github.com/skmp/920357e9d3a7733234ade1eb465367cc), which is required to have your changes merged.

If you are looking for somewhere to start, look for issues marked [good first issue](https://github.com/reicast/reicast-emulator/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) or [help wanted](https://github.com/reicast/reicast-emulator/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)

Supporting the project / donations
-------------------
Well, glad you liked the project so far! We want to switch to a "donation-driven-development" model so that we are not forced to pay out of out pockets for the project costs, and so that contributors can have a source of income to cover food and housing costs.

We accept monetary donations via bountysource at https://salt.bountysource.com/teams/reicast or IBAN transfers to `CH65 0070 0110 0052 6460 1, Stefanos Kornilios Mitsis Poiitidis, 8005 Zürich`. Please note that IBAN donations will appear as `Anonymous` for now.

You can also directly add bounties to tickets that are of interest to you at https://www.bountysource.com/teams/reicast, though supporting the project via a small monthly donation is preffered. Every $5 helps.

We will use the donations to cover administrative and hosting costs (~$100/mo), buy hardware and to sponsor development & testing.

If you want to do hardware or other non-monetary donations, please contact donations@reicast.com.

Please help us to make this project self-sustainable.
Thank you for your support!

Notable Donors
--------------
- Twinaphex / RetroArch Team - introduced us to bountysource, has sponsored the development of a few tickets
- anothername99 - First bounty not posted by RA
- Raco Centrente - First donation from a 3rd party
- (And, of course, all the people that have worked pro-bono over the past 20 years. That is priceless. Thank you!)

Building for Android
--------------------
Tools required:
* Latest Android SDK
 - http://developer.android.com/sdk/index.html
* NDK r8b or newer
 - https://developer.android.com/tools/sdk/ndk/index.html
 - If are not using r9c+, comment the "NDK_TOOLCHAIN_VERSION := 4.8" in shell/android/jni/Application.mk and shell/android/xperia/jni/Application.mk
* Android 5.0.1 (API 21) & Android 2.3.1 (API 9)
 - http://developer.android.com/sdk/installing/adding-packages.html
 - note that API 9 is hidden (you must check to show obsolete in SDK manager)
* Ant
 - http://ant.apache.org/

From project root directory:
```
export ANDROID_NDK=/ # Type the full path to your NDK here

cd shell/android/

android update project -p . --target "android-21"

ant debug
```

Building for iOS / MacOS
---
Requirements:

[Latest Xcode](https://developer.apple.com/xcode/downloads/)

* [iOSOpenDev](http://iosopendev.com/download/) if developing without an official Apple certificate


| iOS            | Mac                    |
| -------------- | ---------------------- |
| An iOS device  | A Mac                  |
| iOS  5.x ~ 7.x | macOS 10.13.3 (17D102) |

From project root directory:

| iOS             | Mac                           |
| --------------- | ----------------------------- |
| `cd shell/ios/` | `cd shell/apple/emulator-osx` |

`xcodebuild -configuration Release`

Or open the .xcodeproj in Xcode and hit "Build".

Building for Linux
------------------
Requirements:
* build-essential
* libasound2
* libegl1-mesa-dev
* libgles2-mesa-dev
* libasound2-dev
* mesa-common-dev
* libgl1-mesa-dev

From project root directory:

```
cd shell/linux

make
```

Translations
------------
New and updated translations are always appreciated!
All we ask is that you not use “regional” phrases that may not be generally understood.

Translations can be submitted as a pull request


Development/Beta versions
-------------
| Platform                                           | Status | Downloads
| -------------------------------------------------- | -------------- | ---------
| ![Android](http://i.imgur.com/nK9exQe.jpg) Android | [![Build Status](https://travis-ci.org/reicast/reicast-emulator.svg?branch=master)](https://travis-ci.org/reicast/reicast-emulator) | [Reicast CI Builds](http://builds.reicast.com)
| ![iOS](http://i.imgur.com/6bvAUUj.png) iOS         | [![Build Status](https://app.bitrise.io/app/d082ed2fb1bdeeef.svg?token=39zhSBFh-b9YVJw8q91omw)](https://app.bitrise.io/app/d082ed2fb1bdeeef#/builds) | *TODO*
| ![Windows](http://i.imgur.com/hAuMmjF.png) Windows | [![Build status](https://ci.appveyor.com/api/projects/status/353mwl73ki74tb58/branch/master?svg=true)](https://ci.appveyor.com/project/skmp/reicast-emulator/branch/master) |  [Reicast CI Builds](http://builds.reicast.com)
| ![Linux](http://i.imgur.com/19aAoQD.png) Linux     | [![wercker status](https://app.wercker.com/status/bcabca642a2de044c6f58203b975878b/s/master "wercker status")](https://app.wercker.com/project/bykey/bcabca642a2de044c6f58203b975878b) | *TODO*
| ![OSX](http://i.imgur.com/0YoI5Vm.png) OSX         | *TODO* | *TODO*


Additional builds (iOS & android) can be found at [angelxwind's](http://reicast.angelxwind.net/) buildbot and [Random Stuff "Daily/Nightly/Testing" PPA](https://launchpad.net/~random-stuff/+archive/ubuntu/ppa) (for Ubuntu).


Other Testing
-------------
Devices tested by the reicast team:
* Apple iPhone 4 GSM Rev0 (N90AP)
* Apple iPhone 4 CDMA (N92AP)
* Apple iPod touch 4 (N81AP)
* Apple iPod touch 3G (N18AP)
* Apple iPhone 3GS (N88AP)
* Apple iPhone 5s
* Apple iPad 3
* Sony Xperia X10a (es209ra)
* Amazon Kindle Fire HD 7 (tate-pvt-08)
* Nvidia Shield portable
* Nvidia Shield tablet
* Samsung Galaxy Note 4
* LG Nexus 5
* LG Nexus 5X
* Asus Nexus 7 (2013)


Team
----

You can check the currently active committers on [the pretty graphs page](https://github.com/reicast/reicast-emulator/graphs/contributors)

Our IRC channel is [#reicast @ chat.freenode.net](irc://chat.freenode.net/reicast).

The original reicast team consisted of drk||Raziel (mostly just writing code),
PsyMan (debugging/testing and everything else) and a little bit of gb_away


Special thanks
--------------
In previous iterations a lot of people have worked on this, notably David
Miller (aka, ZeZu), the nullDC team, friends from #pcsx2 and all over the world :)

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/reicast/reicast-emulator/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

