fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew install fastlane`

# Available Actions
## iOS
### ios build_developer
```
fastlane ios build_developer
```
Exports a new Developer Build
### ios build_appstore
```
fastlane ios build_appstore
```
Exports a new AppStore Build
### ios build_beta
```
fastlane ios build_beta
```
Provenace Team: Push a new beta build to TestFlight
### ios build_alpha
```
fastlane ios build_alpha
```
Provenace Team: Push a new alpha build to Hockeyapp
### ios userbuild
```
fastlane ios userbuild
```
User Builds
### ios certificates_download
```
fastlane ios certificates_download
```
Download Certs for Match
### ios certificates_update
```
fastlane ios certificates_update
```
Create Certs for Match
### ios update_devices
```
fastlane ios update_devices
```
Update device UDID list in iTunes connect from fastlane/devices.txt
### ios default_changelog
```
fastlane ios default_changelog
```

### ios travis
```
fastlane ios travis
```
Travis building iOS & tvOS
### ios travis_ios
```
fastlane ios travis_ios
```
Travis building iOS
### ios travis_tvos
```
fastlane ios travis_tvos
```
Travis building tvOS
### ios test
```
fastlane ios test
```
Build and run tests
### ios derived_data
```
fastlane ios derived_data
```
Clear your DerivedData
### ios reset_checkout
```
fastlane ios reset_checkout
```
Reset build enviroment

Use this lane if you're having build issues

Use `git stash` first to save any changes you may want to keep.
### ios check_env
```
fastlane ios check_env
```
Print Environment Settings
### ios updatePlistForBranch
```
fastlane ios updatePlistForBranch
```
Updates the bundle id and app name if a beta build
### ios plist_reset
```
fastlane ios plist_reset
```
Resets the bundle id and app name after build

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
