# Change Log
All notable changes to MIKMIDI are documented in this file. This project adheres to [Semantic Versioning](http://semver.org/).

##[Unreleased]
This section is for recent changes not yet included in an official release.

##[1.6.2] - 2017-11-09

### ADDED

- System Exclusive multi-packet coalescing (#200)
- `MIKMIDISystemKeepAliveCommand` for keep alive messages
- `MIKMIDIPacketCreateFromCommands()`
- Convenience method for creating control change commands

### FIXED

- `-[MIKMIDIDeviceManager connectedDevices]` is no longer always nil (#162)
- Incorrect MIKMIDIClock timing on iOS devices (#180 and #199)
- Incorrect metaDataType on instances of `MIKMIDIMetaEvent` subclasses (#151)
- Minor GCD queue creation bug (#204)
- Parsing multiple MIDI messages of different types in a single incoming packet (#201)
- Buffer overflow in `-[MIKMIDISystemExclusiveCommand manufacturerID]` (#197)
- Memory leak in `MIKStringPropertyFromMIDIObject()` (#206)
- Retain cycle between `MIKMIDISequence` and `MIKMIDISequencer` (#205)
- Bug that caused note offs to be scheduled early by `MIKMIDISequencer`
- Frequent hash collisions between instances of `MIKMIDIObject` (#181)
- Minor Swift incompatibilities

##[1.6.1] - 2016-11-04

### ADDED

- MIDI To Audio example project showing how to use MIKMIDI to do offline rendering of MIDI to an audio file. (#164)

### FIXED

- Incorrect nullability annotations for MIKMIDINoteEvent convenience methods.
- Minor documentation mistakes.
- Updated example projects for Xcode 8.

### CHANGED

- Moved macOS example projects into a "macOS" subfolder of Examples.
- Email address for maintainer (Andrew Madsen).

##[1.6.0] - 2016-06-01

### ADDED

- `MIKMIDISequencer` now respects the offset, muted, and solo properties of `MIKMIDITrack`. (#99)
- Error-returning variant of `-[MIKMIDISequence addTrack:]`, `-addTrackWithError:`. `-addTrack:` is now deprecated. (#134)
- Added `maximumLookAheadInterval` property to `MIKMIDISequencer` (ac8142b)
- Fixed issue where click track events would be added to the beginning of a loop when the status was EnabledOnlyInPreRoll. (2535c5b)
- Convenience initializers for `MIKMIDINoteOn/OffCommand` that take `MIDITimeStamp`s instead of `NSDate`s. (0bf4a00)
- Custom initializers for several `MIKMIDIMetaEvent` subclasses, greatly simplifing their creation. (#150)
- `MIKMIDIPacketCreate()` function to ease creating `MIDIPacket` structs in Swift. (a12f121)

### CHANGED

- Improved support for subclassing `MIKMIDISynthesizer` and customizing MIDI event scheduling (87b38ea)

### FIXED

- Issue where `MIKMIDISequencer` would almost immediately stop recording if its sequence was empty. (#45)
- `MIKMIDIMetronome` allows loading soundfonts. (a50ccdf)
- Issue with stuck notes in `MIKMIDISequencer`'s pre-roll. (07a9304)
- `MIKMIDISequencer` now ignores incoming MIDI in recording mode during the pre-roll. (2312e4d)
- Potentional crash in `MIKMIDISequencer`. (4c0ce02)
- `MIKMIDIGetCurrentTimeStamp()` is now available in Swift (658cb63)
- Scheduling issues in `MIKMIDISynthesizer` (6698fad)
- Updated MIDI Files Testbed to fix deprecation warnings.
- Improved MIDI Soundboard example for iOS (#119, d0ada0a, a35ee94)
- Incorrect length for some `MIKMIDICommand` subclass instances when created with alloc/init. (#125)
- Incorrect MSB calculation for pitch bend commands. (#147, thanks to akmidd)
- Bug in logic for detecting and exposing available virtual sources and destinations (#144, #145, thanks to jrmaxdev)


### DEPRECATED
This release deprecates a number of existing MIKMIDI APIs. These APIs remain available, and functional, but developers should switch to the use of their replacements as soon as possible.

- `-[MIKMIDISequence addTrack:]`. Use `-addTrackWithError:` instead. (#134)

##[1.5.0] - 2015-11-14
### ADDED
- `MIKMIDISynthesizer` for general-purpose MIDI synthesis. `MIKMIDIEndpointSynthesizer` is now a subclass of `MIKMIDISynthesizer`.
- `MIKMIDISequencer` now has API for routing tracks to MIDI endpoints, synthesizers, 
or other command scheduling objects (`-(setC|c)ommandScheduler:forTrack:`)
- Nullability and Objective-C generics annotations for much nicer usage from Swift. (#39 & #108)
- API for loading soundfont files using `-[MIKMIDISynthesizer loadSoundfontFromFileAtURL:error:]`. (#47) 
- Added `MIKMIDIEvent` subclass `MIKMIDIChannelEvent` and related children (`MIKMIDIPitchBendChangeEvent`, `MIKMIDIControlChangeEvent`, etc.). (#63)
- Added `MIKMIDIChannelVoiceCommand` subclasses for remaining MIDI channel voice message types (pitch bend, polyphonic key pressure, channel pressure). (#65)
- API on `MIKMIDISequence` to control whether channels are split into individual tracks or not. (#66)
- Preliminary unit tests (still need a lot more coverage with tests).
- API on `MIKMIDISequencer` to set playback tempo (overrides sequence tempo). (#81)
- Ability to explicitly stop `MIKMIDIMappingGenerator`'s mapping via `-[MIKMIDIMappingGenerator endMapping]`. (#84)
- Looping API on `MIKMIDISequencer` (#85)
- API for syncing `MIKMIDIClock`s (see `-[MIKMIDIClock syncedClock]`). (#86)
- Ability to suspend MIDI mapping generation, then later resume right where it left off (`-[MIKMIDIMappingGenerator suspendMapping/resumeMapping]`). (#102)
- API for customizing mapping file naming. See `MIKMIDIMappingManagerDelegate`. (#114)
- `MIKMIDIConnectionManager` which implements a generic MIDI device connection manager including support for saving/restoring connection configuration to NSUserDefaults, etc. (#106)
- Other minor API additions and improvements. (#87, #89, #90, #93, #94)

### CHANGED
- `MIKMIDIEndpointSynthesizerInstrument` was renamed to `MIKMIDISynthesizerInstrument`. This **does not** break existing code, due to the use of `@compatibility_alias`
- `MIKMIDISequencer` creates and uses default synthesizers for each track, allowing a minimum of configuration for simple MIDI playback. (#34)
- `MIKMIDISequence` and `MIKMIDITrack` are now KVO compliant for most of their properties. Check documentation for specifics. (#35 & #67)
- `MIKMIDISequencer` can now send MIDI to any object that conforms to the new `MIKMIDICommandScheduler` protocol. Removes the need to use virtual endpoints for internal scheduling. (#36)
- Significantly improved performance of MIDI responder hierarchy search code, including adding (optional) caching. (#82)
- Improved `MIKMIDIDeviceManager` API to simplify device disconnection, in particular. (#109)

### FIXED
- `MIKMIDIEndpointSynthesizer` had too much reverb by default. (#38)
- `MIKMIDISequencer`'s playback would stall or drop notes when the main thread was busy/blocked. Processing is now done in the background. (#48 & #92)
- `MIKMIDIEvent` (or subclass) instances created with `alloc/init` no longer have a NULL `eventType`. (#59)
- Warnings when using MIKMIDI.framework in a Swift project. (#64)
- Bug that could cause `MIKMIDISequencer` to sometimes skip the first events in its sequence upon starting playback. (#95)
- Occasional crash (in `MIKMIDIEventIterator`) during `MIKMIDISequencer` playback. (#100)
- KVO notifications for `MIKMIDIDeviceManager`'s `availableDevices` property now includ valid `NSKeyValueChangeOld/NewKey` entries and associated values. (#112)
- Exception is no longer thrown when setting "empty" `MIKMutableMIDIMetaTimeSignatureEvent`'s numerator. (#57)
- Other minor bug fixes (#71, #83)

### DEPRECATED
This release deprecates a number of existing MIKMIDI APIs. These APIs remain available, and functional, but developers should switch to the use of their replacements as soon as possible.  

- `-[MIKMIDITrack getTrackNumber:]`. Use `trackNumber` @property on `MIKMIDITrack` instead.
- `-[MIKMIDISequence getTempo:atTimeStamp:]`. Use `-tempoAtTimeStamp:` instead.
- `-[MIKMIDISequence getTimeSignature:atTimeStamp:]`. Use `-timeSignatureAtTimeStamp:` instead.
- `doesLoop`, `numberOfLoops`, `loopDuration`, and `loopInfo` on `MIKMIDITrack`. These methods affect looping when using `MIKMIDIPlayer`, but not `MIKMIDISequencer`. Use `-[MIKMIDISequencer setLoopStartTimeStamp:endTimeStamp:]` instead.
- `-insertMIDIEvent:`, `-insertMIDIEvents:`, `-removeMIDIEvents:`, and `-clearAllEvents` on MIKMIDITrack. Use `-addEvent:`, `-removeEvent:`, `-removeAllEvents` instead.
- `-[MIKMIDIDeviceManager disconnectInput:forConnectionToken:]`. Use `-disconnectConnectionForToken:` instead.
- `-setMusicTimeStamp:withTempo:atMIDITimeStamp:`, `+secondsPerMIDITimeStamp`, `+midiTimeStampsPerTimeInterval:` on `MIKMIDIClock`. See documentation for replacement API.
- `+[MIKMIDICommand supportsMIDICommandType:]`. Use `+[MIKMIDICommand supportedMIDICommandTypes]` instead. This is only relevant when creating custom subclasses of `MIKMIDICommand`, which most MIKMIDI users do not need to do. (#57)

##[1.0.1] - 2015-04-20

### ADDED
- Support for [Carthage](https://github.com/Carthage/Carthage)
- Better error handling for `MIKMIDIClientSource/DestinationEndpoint`, particularly on iOS.
- `MIKMIDISequence` initializer methods that include an error parameter.

### CHANGED
- Improved documentation.

### FIXED
- `MIKMIDIMetronome` on iOS (8).
- `MIKMIDICommand`'s channel now defaults to 0 as it should.

### DEPRECATED
- `-[MIKMIDISequence initWithData:]`. Use `-[MIKMIDISequence initWithData:error:]`, instead.
- `+[MIKMIDISequence sequenceWithData:]`. Use `+[MIKMIDISequence sequenceWithData:error:]`, instead.
- `-[MIKMIDISequence/MIKMIDITrack setDestinationEndpoint:]`. Use API on MIKMIDISequencer instead.

##[1.0.0] - 2015-01-29
### ADDED
- MIDI Files Testbed OS X example app
- Added `MIKMIDISequence`, `MIKMIDITrack`, `MIKMIDIEvent`, etc. to support loading, creating, saving MIDI files
- API on `MIKMIDIManager` to allow obtaining only bundled or user mappings
- `MIKMIDIPlayer` for playing MIDI files
- Preliminary (experimental/incomplete) implementation of `MIKMIDISequencer` for both playback and recording
- `MIKMIDIEndpointSynthesizerInstrument` and associated instrument selection API for MIDI synthesis
- API (`MIKMIDIClientSource/DestinationEndpoint`) for creating virtual MIDI endpoints
- iOS framework target.

### CHANGED

- Improved README.

### FIXED
- Fixed bug where sending a large number of MIDI messages at a time could fail.
- `MIKMIDIMapping` save/load is now supported on iOS.
- Warnings when building for iOS.

##[0.9.2] - 2014-06-13
### ADDED
- Added `MIKMIDIEndpointSynthesizer` for synthesizing incoming MIDI (OS X only for now).
- Added Cocoapods podspec file to repository.

### FIXED
- `MIKMIDIInputPort` can parse multiple MIDI messages out of a single packet.

##[0.9.1] - 2014-05-24
### FIXED
Minor documentation typo fixes.

##[0.9.0] - 2014-05-16
### ADDED
Initial release