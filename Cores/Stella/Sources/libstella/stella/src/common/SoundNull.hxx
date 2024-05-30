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

#ifndef SOUND_NULL_HXX
#define SOUND_NULL_HXX

class OSystem;
class AudioQueue;
class EmulationTiming;

#include "bspf.hxx"
#include "Logger.hxx"
#include "Sound.hxx"

/**
  This class implements a Null sound object, where-by sound generation
  is completely disabled.

  @author Stephen Anthony
*/
class SoundNull : public Sound
{
  public:
    /**
      Create a new sound object.  The init method must be invoked before
      using the object.
    */
    explicit SoundNull(OSystem& osystem) : Sound(osystem)
    {
      Logger::info("Sound disabled.\n");
    }
    ~SoundNull() override = default;

  public:
    /**
      Enables/disables the sound subsystem.

      @param state  True or false, to enable or disable the sound system
    */
    void setEnabled(bool state) override { }

    /**
      Initializes the sound device.  This must be called before any
      calls are made to derived methods.
    */
    void open(shared_ptr<AudioQueue>, EmulationTiming*) override { }

    /**
      Sets the sound mute state; sound processing continues.  When turned
      off, sound volume is 0; when turned on, sound volume returns to
      previously set level.

      @param state Mutes sound if true, unmute if false
    */
    void mute(bool state) override { }

    /**
      Toggles the sound mute state; sound processing continues.
      Switches between mute(true) and mute(false).
    */
    void toggleMute() override { }

    /**
      Set the pause state of the sound object.  While paused, sound is
      neither played nor processed (ie, the sound subsystem is temporarily
      disabled).

      @param state Pause sound if true, unpause if false

      @return  The previous (old) pause state
    */
    bool pause(bool state) override { return false; }

    /**
      Sets the volume of the sound device to the specified level.  The
      volume is given as a range from 0 to 100 (0 indicates mute).  Values
      outside this range indicate that the volume shouldn't be changed at all.

      @param volume  The new volume level for the sound device
    */
    void setVolume(uInt32 volume) override { }

    /**
      Adjusts the volume of the sound device based on the given direction.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void adjustVolume(int direction = 1) override { }

    /**
      This method is called to provide information about the sound device.
    */
    string about() const override { return "Sound disabled"; }

  protected:
    /**
      This method is called to query the audio devices.

      @param devices  List of device names
    */
    void queryHardware(VariantList& devices) override { }

  private:
    // Following constructors and assignment operators not supported
    SoundNull() = delete;
    SoundNull(const SoundNull&) = delete;
    SoundNull(SoundNull&&) = delete;
    SoundNull& operator=(const SoundNull&) = delete;
    SoundNull& operator=(SoundNull&&) = delete;
};

#endif
