fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build_developer

```sh
[bundle exec] fastlane ios build_developer
```

Exports a new Developer Build

### ios build_appstore

```sh
[bundle exec] fastlane ios build_appstore
```

Exports a new AppStore Build

### ios build_beta

```sh
[bundle exec] fastlane ios build_beta
```

Provenace Team: Push a new beta build to TestFlight

### ios build_alpha

```sh
[bundle exec] fastlane ios build_alpha
```

Provenace Team: Push a new alpha build to Hockeyapp

### ios userbuild

```sh
[bundle exec] fastlane ios userbuild
```

User Builds

### ios certificates_download

```sh
[bundle exec] fastlane ios certificates_download
```

Download Certs for Match

### ios certificates_update

```sh
[bundle exec] fastlane ios certificates_update
```

Create Certs for Match

### ios update_devices

```sh
[bundle exec] fastlane ios update_devices
```

Update device UDID list in iTunes connect from fastlane/devices.txt

### ios default_changelog

```sh
[bundle exec] fastlane ios default_changelog
```



### ios travis

```sh
[bundle exec] fastlane ios travis
```

Travis building iOS & tvOS

### ios travis_ios

```sh
[bundle exec] fastlane ios travis_ios
```

Travis building iOS

### ios travis_tvos

```sh
[bundle exec] fastlane ios travis_tvos
```

Travis building tvOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Build and run tests

### ios derived_data

```sh
[bundle exec] fastlane ios derived_data
```

Clear your DerivedData

### ios reset_checkout

```sh
[bundle exec] fastlane ios reset_checkout
```

Reset build enviroment

Use this lane if you're having build issues

Use `git stash` first to save any changes you may want to keep.

### ios check_env

```sh
[bundle exec] fastlane ios check_env
```

Print Environment Settings

### ios updatePlistForBranch

```sh
[bundle exec] fastlane ios updatePlistForBranch
```

Updates the bundle id and app name if a beta build

### ios plist_reset

```sh
[bundle exec] fastlane ios plist_reset
```

Resets the bundle id and app name after build

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
