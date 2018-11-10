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
or alternatively using `brew cask install fastlane`

# Available Actions
### derived_data
```
fastlane derived_data
```
Clear your DerivedData
### reset_checkout
```
fastlane reset_checkout
```
Reset build enviroment

Use this lane if you're having build issues

Use `git stash` first to save any changes you may want to keep.
### check_env
```
fastlane check_env
```
Print Environment Settings
### updatePlistForBranch
```
fastlane updatePlistForBranch
```
Updates the bundle id and app name if a beta build
### plist_reset
```
fastlane plist_reset
```
Resets the bundle id and app name after build

----

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
### ios carthage_bootstrap_ios
```
fastlane ios carthage_bootstrap_ios
```
Lane to run bootstrap carthage in new checkout for iOS only
### ios carthage_bootstrap_tvos
```
fastlane ios carthage_bootstrap_tvos
```
Lane to run bootstrap carthage in new checkout for tvOS only
### ios carthage_bootstrap
```
fastlane ios carthage_bootstrap
```
Lane to run bootstrap carthage in new checkout

Option: `platform` tvOS,iOS
### ios carthage_build
```
fastlane ios carthage_build
```
Lane to run build all carthage dependencies

Option: `platform` tvOS,iOS
### ios carthage_build_ios
```
fastlane ios carthage_build_ios
```
Lane to run build all carthage dependencies - iOS
### ios carthage_build_tvos
```
fastlane ios carthage_build_tvos
```
Lane to run build all carthage dependencies - tvOS
### ios carthage_update
```
fastlane ios carthage_update
```
Lane to update all carthage dependencies to latest versions

Option: `platform` tvOS,iOS
### ios carthage_update_ios
```
fastlane ios carthage_update_ios
```
Lane to update all carthage dependencies to latest versions for iOS only
### ios carthage_update_tvos
```
fastlane ios carthage_update_tvos
```
Lane to update all carthage dependencies to latest versions for tvOS only
### ios rome_download
```
fastlane ios rome_download
```
Download cached Rome builds
### ios rome_upload
```
fastlane ios rome_upload
```
Upload cached Rome builds
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
Update device UDID list in iTunes connect from fastlane/devices.text
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

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
