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

#ifndef MEDIA_FACTORY_HXX
#define MEDIA_FACTORY_HXX

#include "bspf.hxx"
#if defined(SDL_SUPPORT)
  #include "SDL_lib.hxx"
#endif

#include "OSystem.hxx"
#include "Settings.hxx"
#include "SerialPort.hxx"
#if defined(BSPF_UNIX)
  #include "SerialPortUNIX.hxx"
  #if defined(RETRON77)
    #include "SettingsR77.hxx"
    #include "OSystemR77.hxx"
  #else
    #include "OSystemUNIX.hxx"
  #endif
#elif defined(BSPF_WINDOWS)
  #include "SerialPortWINDOWS.hxx"
  #include "OSystemWINDOWS.hxx"
#elif defined(BSPF_MACOS)
  #include "SerialPortMACOS.hxx"
  #include "OSystemMACOS.hxx"
  extern "C" {
    int stellaMain(int argc, char* argv[]);
  }
#elif defined(__LIB_RETRO__)
  #include "OSystemLIBRETRO.hxx"
#else
  #error Unsupported platform!
#endif

#if defined(__LIB_RETRO__)
  #include "EventHandlerLIBRETRO.hxx"
  #include "FBBackendLIBRETRO.hxx"
#elif defined(SDL_SUPPORT)
  #include "EventHandlerSDL2.hxx"
  #include "FBBackendSDL2.hxx"
#else
  #error Unsupported backend!
#endif

#if defined(SOUND_SUPPORT)
  #if defined(__LIB_RETRO__)
    #include "SoundLIBRETRO.hxx"
  #elif defined(SDL_SUPPORT)
    #include "SoundSDL2.hxx"
  #else
    #include "SoundNull.hxx"
  #endif
#else
  #include "SoundNull.hxx"
#endif

class AudioSettings;

/**
  This class deals with the different framebuffer/sound/event
  implementations for the various ports of Stella, and always returns a
  valid object based on the specific port and restrictions on that port.

  As of SDL2, this code is greatly simplified.  However, it remains here
  in case we ever have multiple backend implementations again (should
  not be necessary since SDL2 covers this nicely).

  @author  Stephen Anthony
*/
class MediaFactory
{
  public:
    static unique_ptr<OSystem> createOSystem()
    {
    #if defined(BSPF_UNIX)
      #if defined(RETRON77)
        return make_unique<OSystemR77>();
      #else
        return make_unique<OSystemUNIX>();
      #endif
    #elif defined(BSPF_WINDOWS)
      return make_unique<OSystemWINDOWS>();
    #elif defined(BSPF_MACOS)
      return make_unique<OSystemMACOS>();
    #elif defined(__LIB_RETRO__)
      return make_unique<OSystemLIBRETRO>();
    #else
      #error Unsupported platform for OSystem!
    #endif
    }

    static unique_ptr<Settings> createSettings()
    {
    #ifdef RETRON77
      return make_unique<SettingsR77>();
    #else
      return make_unique<Settings>();
    #endif
    }

    static unique_ptr<SerialPort> createSerialPort()
    {
    #if defined(BSPF_UNIX)
      return make_unique<SerialPortUNIX>();
    #elif defined(BSPF_WINDOWS)
      return make_unique<SerialPortWINDOWS>();
    #elif defined(BSPF_MACOS)
      return make_unique<SerialPortMACOS>();
    #else
      return make_unique<SerialPort>();
    #endif
    }

    static unique_ptr<FBBackend> createVideoBackend(OSystem& osystem)
    {
    #if defined(__LIB_RETRO__)
      return make_unique<FBBackendLIBRETRO>(osystem);
    #elif defined(SDL_SUPPORT)
      return make_unique<FBBackendSDL2>(osystem);
    #else
      #error Unsupported platform for FrameBuffer!
    #endif
    }

    static unique_ptr<Sound> createAudio(OSystem& osystem, AudioSettings& audioSettings)
    {
    #if defined(SOUND_SUPPORT)
      #if defined(__LIB_RETRO__)
        return make_unique<SoundLIBRETRO>(osystem, audioSettings);
      #elif defined(SOUND_SUPPORT) && defined(SDL_SUPPORT)
        return make_unique<SoundSDL2>(osystem, audioSettings);
      #else
        return make_unique<SoundNull>(osystem);
      #endif
    #else
      return make_unique<SoundNull>(osystem);
    #endif
    }

    static unique_ptr<EventHandler> createEventHandler(OSystem& osystem)
    {
    #if defined(__LIB_RETRO__)
      return make_unique<EventHandlerLIBRETRO>(osystem);
    #elif defined(SDL_SUPPORT)
      return make_unique<EventHandlerSDL2>(osystem);
    #else
      #error Unsupported platform for EventHandler!
    #endif
    }

    static void cleanUp()
    {
    #if defined(SDL_SUPPORT)
      SDL_Quit();
    #endif
    }

    static string backendName()
    {
    #if defined(SDL_SUPPORT)
      return SDLVersion();
    #else
      return "Custom backend";
    #endif
    }

    static bool openURL(const string& url)
    {
    #if defined(SDL_SUPPORT)
      return SDLOpenURL(url);
    #else
      return false;
    #endif
    }

  private:
    // Following constructors and assignment operators not supported
    MediaFactory() = delete;
    MediaFactory(const MediaFactory&) = delete;
    MediaFactory(MediaFactory&&) = delete;
    MediaFactory& operator=(const MediaFactory&) = delete;
    MediaFactory& operator=(MediaFactory&&) = delete;
};

#endif
