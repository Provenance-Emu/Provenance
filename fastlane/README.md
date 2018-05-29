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
## iOS
### ios test
```
fastlane ios test
```
Build and run tests
### ios travistest
```
fastlane ios travistest
```
Travis Test
### ios userbuild
```
fastlane ios userbuild
```
User Setup
### ios beta
```
fastlane ios beta
```
Push a new beta build to TestFlight
### ios alpha
```
fastlane ios alpha
```
Push a new alpha build to Hockeyapp
### ios certificates
```
fastlane ios certificates
```
Setup Certs for Match - New Devs
### ios create_certificates
```
fastlane ios create_certificates
```
Create Certs for Match
### ios update_devices
```
fastlane ios update_devices
```
Update device list
### ios derived_data
```
fastlane ios derived_data
```
Clear your DerivedData

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
