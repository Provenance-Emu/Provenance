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

#ifdef SOUND_SUPPORT

#ifndef SOUND_SDL2_HXX
#define SOUND_SDL2_HXX

class OSystem;
class AudioQueue;
class EmulationTiming;
class AudioSettings;
class Resampler;

#include "SDL_lib.hxx"

#include "bspf.hxx"
#include "Sound.hxx"

/**
  This class implements the sound API for SDL.

  @author Stephen Anthony and Christian Speckner (DirtyHairy)
*/
class SoundSDL2 : public Sound
{
  public:
    /**
      Create a new sound object.  The init method must be invoked before
      using the object.
    */
    SoundSDL2(OSystem& osystem, AudioSettings& audioSettings);

    /**
      Destructor
    */
    ~SoundSDL2() override;

  public:
    /**
      Enables/disables the sound subsystem.

      @param enable  Either true or false, to enable or disable the sound system
    */
    void setEnabled(bool enable) override;

    /**
      Initializes the sound device.  This must be called before any
      calls are made to derived methods.
    */
    void open(shared_ptr<AudioQueue> audioQueue, EmulationTiming* emulationTiming) override;

    /**
      Should be called to close the sound device.  Once called the sound
      device can be started again using the open method.
    */
    void close() override;

    /**
      Set the mute state of the sound object.  While muted no sound is played.

      @param state Mutes sound if true, unmute if false

      @return  The previous (old) mute state
    */
    bool mute(bool state) override;

    /**
      Toggles the sound mute state.  While muted no sound is played.

      @return  The previous (old) mute state
    */
    bool toggleMute() override;

    /**
      Sets the volume of the sound device to the specified level.  The
      volume is given as a percentage from 0 to 100.  Values outside
      this range indicate that the volume shouldn't be changed at all.

      @param percent  The new volume percentage level for the sound device
    */
    void setVolume(uInt32 percent) override;

    /**
      Adjusts the volume of the sound device based on the given direction.

      @param direction  +1 indicates increase, -1 indicates decrease.
      */
    void adjustVolume(int direction = 1) override;

    /**
      This method is called to provide information about the sound device.
    */
    string about() const override;

  protected:
    /**
      This method is called to query the audio devices.

      @param devices  List of device names
    */
    void queryHardware(VariantList& devices) override;

    /**
      Invoked by the sound callback to process the next sound fragment.
      The stream is 16-bits (even though the callback is 8-bits), since
      the TIASnd class always generates signed 16-bit stereo samples.

      @param stream  Pointer to the start of the fragment
      @param length  Length of the fragment
    */
    void processFragment(float* stream, uInt32 length);

  private:
    /**
      The actual sound device is opened only when absolutely necessary.
      Typically this will only happen once per program run, but it can also
      happen dynamically when changing sample rate and/or fragment size.
    */
    bool openDevice();

    void initResampler();

  private:
    // Indicates if the sound device was successfully initialized
    bool myIsInitializedFlag{false};

    // Current volume as a percentage (0 - 100)
    uInt32 myVolume{100};
    float myVolumeFactor{0xffff};

    // Audio specification structure
    SDL_AudioSpec myHardwareSpec;

    uInt32 myDeviceId{0};

    SDL_AudioDeviceID myDevice{0};

    shared_ptr<AudioQueue> myAudioQueue;

    EmulationTiming* myEmulationTiming{nullptr};

    Int16* myCurrentFragment{nullptr};
    bool myUnderrun{false};

    unique_ptr<Resampler> myResampler;

    AudioSettings& myAudioSettings;

    string myAboutString;

  private:
    // Callback function invoked by the SDL Audio library when it needs data
    static void callback(void* udata, uInt8* stream, int len);

    // Following constructors and assignment operators not supported
    SoundSDL2() = delete;
    SoundSDL2(const SoundSDL2&) = delete;
    SoundSDL2(SoundSDL2&&) = delete;
    SoundSDL2& operator=(const SoundSDL2&) = delete;
    SoundSDL2& operator=(SoundSDL2&&) = delete;
};

#endif

#endif  // SOUND_SUPPORT
