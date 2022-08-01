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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
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
      Should be called to stop the sound system.  Once called the sound
      device can be started again using the ::open() method.
    */
    virtual void close() = 0;

    /**
      Set the mute state of the sound object.  While muted no sound is played.

      @param state Mutes sound if true, unmute if false

      @return  The previous (old) mute state
    */
    virtual bool mute(bool state) = 0;

    /**
      Toggles the sound mute state.  While muted no sound is played.

      @return  The previous (old) mute state
    */
    virtual bool toggleMute() = 0;

    /**
      Sets the volume of the sound device to the specified level.  The
      volume is given as a percentage from 0 to 100.  Values outside
      this range indicate that the volume shouldn't be changed at all.

      @param percent The new volume percentage level for the sound device
    */
    virtual void setVolume(uInt32 percent) = 0;

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
    const VariantList& supportedDevices() const {return myDevices;}

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
