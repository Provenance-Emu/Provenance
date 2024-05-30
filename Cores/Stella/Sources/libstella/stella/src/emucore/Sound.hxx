//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef SOUND_HXX
#define SOUND_HXX

class OSystem;
class AudioQueue;
class EmulationTiming;

#include "bspf.hxx"
#include "Variant.hxx"

/**
  This class is an abstract base class for the various sound objects.
  It has no functionality whatsoever.

  @author Stephen Anthony
*/
class Sound
{
  public:
    /**
      Create a new sound object.  The open method must be invoked before
      using the object.
    */
    Sound(OSystem& osystem) : myOSystem{osystem} { }
    virtual ~Sound() = default;

  public:
    /**
      Enables/disables the sound subsystem.

      @param enable  Either true or false, to enable or disable the sound system
    */
    virtual void setEnabled(bool enable) = 0;

    /**
      Start the sound system, initializing it if necessary.  This must be
      called before any calls are made to derived methods.
    */
    virtual void open(shared_ptr<AudioQueue>, EmulationTiming*) = 0;

    /**
      Sets the sound mute state; sound processing continues.  When turned
      off, sound volume is 0; when turned on, sound volume returns to
      previously set level.

      @param state Mutes sound if true, unmute if false
    */
    virtual void mute(bool state) = 0;

    /**
      Toggles the sound mute state; sound processing continues.
      Switches between mute(true) and mute(false).
    */
    virtual void toggleMute() = 0;

    /**
      Set the pause state of the sound object.  While paused, sound is
      neither played nor processed (ie, the sound subsystem is temporarily
      disabled).

      @param state Pause sound if true, unpause if false

      @return  The previous (old) pause state
    */
    virtual bool pause(bool state) = 0;

    /**
      Sets the volume of the sound device to the specified level.  The
      volume is given as a range from 0 to 100 (0 indicates mute).  Values
      outside this range indicate that the volume shouldn't be changed at all.

      @param volume  The new volume level for the sound device
    */
    virtual void setVolume(uInt32 volume) = 0;

    /**
      Adjusts the volume of the sound device based on the given direction.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    virtual void adjustVolume(int direction = 1) = 0;

    /**
      This method is called to provide information about the sound device.
    */
    virtual string about() const = 0;

    /**
      Get the supported devices for the audio hardware.

      @return  An array of supported devices
    */
    const VariantList& supportedDevices() const { return myDevices; }

    /**
      Play a WAV file.

      @param fileName  The name of the WAV file
      @param position  The position to start playing
      @param length    The played length

      @return  True, if the WAV file can be played
    */
    virtual bool playWav(const string& fileName, const uInt32 position = 0,
                         const uInt32 length = 0) { return false; }

    /**
      Stop any currently playing WAV file.
    */
    virtual void stopWav() { }

    /**
      Get the size of the WAV file which remains to be played.

      @return  The remaining number of bytes
    */
    virtual uInt32 wavSize() const { return 0; }

  protected:
    /**
      This method is called to query the audio devices.

      @param devices  List of device names
    */
    virtual void queryHardware(VariantList& devices) = 0;

  protected:
    // The OSystem for this sound object
    OSystem& myOSystem;

    // Supported device
    VariantList myDevices;

  private:
    // Following constructors and assignment operators not supported
    Sound() = delete;
    Sound(const Sound&) = delete;
    Sound(Sound&&) = delete;
    Sound& operator=(const Sound&) = delete;
    Sound& operator=(Sound&&) = delete;
};

#endif
