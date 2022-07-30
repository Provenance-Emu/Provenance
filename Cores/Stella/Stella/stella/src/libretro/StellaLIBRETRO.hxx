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

#ifndef STELLA_LIBRETRO_HXX
#define STELLA_LIBRETRO_HXX

#include "bspf.hxx"
#include "OSystemLIBRETRO.hxx"

#include "Cart.hxx"
#include "Console.hxx"
#include "ConsoleTiming.hxx"
#include "Control.hxx"
#include "EmulationTiming.hxx"
#include "EventHandler.hxx"
#include "M6532.hxx"
#include "Paddles.hxx"
#include "PaletteHandler.hxx"
#include "System.hxx"
#include "TIA.hxx"
#include "TIASurface.hxx"

/**
  This class wraps Stella core for easier libretro maintenance
*/
class StellaLIBRETRO
{
  public:
    StellaLIBRETRO();

  public:
    OSystemLIBRETRO& osystem() const { return *myOSystem; }

    bool create(bool logging);
    void destroy();
    void reset() { myOSystem->console().system().reset(); }

    void runFrame();

    bool loadState(const void* data, size_t size);
    bool saveState(void* data, size_t size) const;

  public:
    const char* getCoreName() const { return "Stella"; }
    const char* getROMExtensions() const { return "a26|bin"; }

    void*  getROM() const { return rom_image.get(); }
    uInt32 getROMSize() const { return rom_size; }
    constexpr uInt32 getROMMax() const { return uInt32(Cartridge::maxSize()); }

    uInt8* getRAM() { return system_ram; }
    constexpr uInt32 getRAMSize() const { return 128; }

    size_t getStateSize() const;

    bool   getConsoleNTSC() const { return console_timing == ConsoleTiming::ntsc; }

    float  getVideoAspectPar() const;
    float  getVideoAspect() const;
    bool   getVideoNTSC() const;
    float  getVideoRate() const { return getVideoNTSC() ? 60.0 : 50.0; }

    bool   getVideoReady() const { return video_ready; }
    uInt32 getVideoZoom() const {
      return myOSystem->frameBuffer().tiaSurface().ntscEnabled() ? 2 : 1;
    }
    bool   getVideoResize();

    void*  getVideoBuffer() const;
    uInt32 getVideoWidth() const {
      return getVideoZoom() == 1 ? myOSystem->console().tia().width() : getVideoWidthMax();
    }
    uInt32 getVideoHeight() const {
      return myOSystem->console().tia().height();
    }
    constexpr uInt32 getVideoPitch() const { return getVideoWidthMax() * 4; }

    constexpr uInt32 getVideoWidthMax() const  { return AtariNTSC::outWidth(160); }
    constexpr uInt32 getVideoHeightMax() const { return 312; }

    uInt32 getRenderWidth() const {
      return getVideoZoom() == 1 ? myOSystem->console().tia().width() * 2
                                 : getVideoWidthMax();
    }
    uInt32 getRenderHeight() const {
      return myOSystem->console().tia().height() * getVideoZoom();
    }

    const Common::Rect& getImageRect() const {
      return myOSystem->frameBuffer().imageRect();
    }

    float  getAudioRate() const {
      return getConsoleNTSC() ? (262 * 76 * 60) / 38.0 : (312 * 76 * 50) / 38.0;
    }
    bool   getAudioReady() const { return audio_samples > 0; }
    uInt32 getAudioSize() const  { return audio_samples; }

    Int16* getAudioBuffer() { return audio_buffer.get(); }

  public:
    void   setROM(const char* path, const void* data, size_t size);

    void   setConsoleFormat(uInt32 mode);

    void   setVideoAspectNTSC(uInt32 value) { video_aspect_ntsc = value; };
    void   setVideoAspectPAL(uInt32 value)  { video_aspect_pal = value; };

    void   setVideoFilter(NTSCFilter::Preset mode);
    void   setVideoPalette(const string& mode);
    void   setVideoPhosphor(uInt32 mode, uInt32 blend);

    void   setAudioStereo(int mode);

    void   setInputEvent(Event::Type type, Int32 state) {
             myOSystem->eventHandler().handleEvent(type, state);
    }

    Controller::Type getLeftControllerType() const {
      return myOSystem->console().leftController().type();
    }
    Controller::Type getRightControllerType() const {
      return myOSystem->console().rightController().type();
    }

    void setPaddleJoypadSensitivity(int sensitivity)
    {
      if(getLeftControllerType() == Controller::Type::Paddles)
        static_cast<Paddles&>(myOSystem->console().leftController()).setDigitalSensitivity(sensitivity);
      if(getRightControllerType() == Controller::Type::Paddles)
        static_cast<Paddles&>(myOSystem->console().rightController()).setDigitalSensitivity(sensitivity);
    }

    void setPaddleAnalogSensitivity(int sensitivity)
    {
      if(getLeftControllerType() == Controller::Type::Paddles)
        static_cast<Paddles&>(myOSystem->console().leftController()).setAnalogSensitivity(sensitivity);
      if(getRightControllerType() == Controller::Type::Paddles)
        static_cast<Paddles&>(myOSystem->console().rightController()).setAnalogSensitivity(sensitivity);
    }

  protected:
    void   updateInput();
    void   updateVideo();
    void   updateAudio();

  private:
    // Following constructors and assignment operators not supported
    StellaLIBRETRO(const StellaLIBRETRO&) = delete;
    StellaLIBRETRO(StellaLIBRETRO&&) = delete;
    StellaLIBRETRO& operator=(const StellaLIBRETRO&) = delete;
    StellaLIBRETRO& operator=(StellaLIBRETRO&&) = delete;

    unique_ptr<OSystemLIBRETRO> myOSystem;
    uInt32 system_ready{false};

    ByteBuffer rom_image;
    uInt32 rom_size{0};
    string rom_path;

    ConsoleTiming console_timing{ConsoleTiming::ntsc};
    string console_format{"AUTO"};

    mutable uInt32* render_surface{nullptr};
    uInt32 render_width{0}, render_height{0};

    bool video_ready{false};

    unique_ptr<Int16[]> audio_buffer;
    uInt32 audio_samples{0};

    uInt8 system_ram[128];

    // (31440 rate / 50 Hz) * 16-bit stereo * 1.25x padding
    static constexpr uInt32 audio_buffer_max = (31440 / 50 * 4 * 5) / 4;

  private:
    string video_palette{PaletteHandler::SETTING_STANDARD};
    string video_phosphor{"byrom"};
    uInt32 video_phosphor_blend{60};

    uInt32 video_aspect_ntsc{0};
    uInt32 video_aspect_pal{0};
    NTSCFilter::Preset video_filter{NTSCFilter::Preset::OFF};

    string audio_mode{"byrom"};

    bool phosphor_default{false};
};

#endif
