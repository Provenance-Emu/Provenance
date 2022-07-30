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

#include "bspf.hxx"
#include "StellaLIBRETRO.hxx"
#include "SoundLIBRETRO.hxx"
#include "FBBackendLIBRETRO.hxx"
#include "FBSurfaceLIBRETRO.hxx"

#include "AtariNTSC.hxx"
#include "AudioSettings.hxx"
#include "Serializer.hxx"
#include "StateManager.hxx"
#include "Switches.hxx"
#include "TIA.hxx"
#include "TIASurface.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StellaLIBRETRO::StellaLIBRETRO()
  : rom_image{make_unique<uInt8[]>(getROMMax())},
    audio_buffer{make_unique<Int16[]>(audio_buffer_max)}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StellaLIBRETRO::create(bool logging)
{
  system_ready = false;

  // build play system
  destroy();

  myOSystem = make_unique<OSystemLIBRETRO>();

  Settings::Options options;
  myOSystem->initialize(options);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  Settings& settings = myOSystem->settings();

  if(logging)
  {
    settings.setValue("loglevel", 999);
    settings.setValue("logtoconsole", true);
  }

  settings.setValue("speed", 1.0);
  settings.setValue("uimessages", false);

  settings.setValue("format", console_format);
  settings.setValue("palette", video_palette);

  settings.setValue("tia.zoom", 1);
  settings.setValue("tia.vsizeadjust", 0);
  settings.setValue("tia.inter", false);

  //fastscbios
  // Fast loading of Supercharger BIOS

  settings.setValue("tv.filter", static_cast<int>(video_filter));

  settings.setValue("tv.phosphor", video_phosphor);
  settings.setValue("tv.phosblend", video_phosphor_blend);

  /*
  31440 rate

  fs:2 hz:50 bs:314.4 -- not supported,      0 frame lag ideal
  fs:128 hz:50 bs:4.9 -- lowest supported, 0-1 frame lag measured
  */
  settings.setValue(AudioSettings::SETTING_PRESET, static_cast<int>(AudioSettings::Preset::custom));
  settings.setValue(AudioSettings::SETTING_SAMPLE_RATE, getAudioRate());
  settings.setValue(AudioSettings::SETTING_FRAGMENT_SIZE, 128);
  settings.setValue(AudioSettings::SETTING_BUFFER_SIZE, 8);
  settings.setValue(AudioSettings::SETTING_HEADROOM, 0);
  settings.setValue(AudioSettings::SETTING_RESAMPLING_QUALITY, static_cast<int>(AudioSettings::ResamplingQuality::nearestNeightbour));
  settings.setValue(AudioSettings::SETTING_VOLUME, 100);
  settings.setValue(AudioSettings::SETTING_STEREO, audio_mode);

  FSNode rom(rom_path);

  if(myOSystem->createConsole(rom) != EmptyString)
    return false;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  console_timing = myOSystem->console().timing();
  phosphor_default = myOSystem->frameBuffer().tiaSurface().phosphorEnabled();

  if(video_phosphor == "never") setVideoPhosphor(1, video_phosphor_blend);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  video_ready = false;
  audio_samples = 0;

  system_ready = true;
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::destroy()
{
  system_ready = false;

  video_ready = false;
  audio_samples = 0;

  myOSystem.reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::runFrame()
{
  // write ram updates
  for(int lcv = 0; lcv <= 127; lcv++)
    myOSystem->console().system().m6532().poke(lcv | 0x80, system_ram[lcv]);

  // poll input right at vsync
  updateInput();

  // run vblank routine and draw frame
  updateVideo();

  // drain generated audio
  updateAudio();

  // refresh ram copy
  memcpy(system_ram, myOSystem->console().system().m6532().getRAM(), 128);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::updateInput()
{
  const Console& console = myOSystem->console();

  console.leftController().update();
  console.rightController().update();

  console.switches().update();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::updateVideo()
{
  TIA& tia = myOSystem->console().tia();

  while (1)
  {
    tia.updateScanline();

    if(tia.scanlines() == 0) break;
  }

  video_ready = tia.newFramePending();

  if (video_ready)
  {
    FrameBuffer& frame = myOSystem->frameBuffer();

    tia.renderToFrameBuffer();
    frame.updateInEmulationMode(0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::updateAudio()
{
  static_cast<SoundLIBRETRO&>(myOSystem->sound()).dequeue(audio_buffer.get(), &audio_samples);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StellaLIBRETRO::loadState(const void* data, size_t size)
{
  Serializer state;

  state.putByteArray(reinterpret_cast<const uInt8*>(data), size);

  if(!myOSystem->state().loadState(state))
    return false;

  memcpy(system_ram, myOSystem->console().system().m6532().getRAM(), 128);
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StellaLIBRETRO::saveState(void* data, size_t size) const
{
  Serializer state;

  if (!myOSystem->state().saveState(state))
    return false;

  if (state.size() > size)
    return false;

  state.getByteArray(reinterpret_cast<uInt8*>(data), state.size());
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t StellaLIBRETRO::getStateSize() const
{
  Serializer state;

  if (!myOSystem->state().saveState(state))
    return 0;

  return state.size();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
float StellaLIBRETRO::getVideoAspectPar() const
{
  float par;

  if (getVideoNTSC())
  {
    if (!video_aspect_ntsc)
    {
      if (video_filter != NTSCFilter::Preset::OFF)
      {
        // non-interlace square pixel clock -- 1.0 pixel @ color burst -- double-width pixels
        par = (6.1363635f / 3.579545454f) / 2.0;
      }
      else
      {
        // blargg filter
        par = 1.0;
      }
    }
    else
      par = video_aspect_ntsc / 100.0;
  }
  else
  {
    if (!video_aspect_pal)
    {
      if (video_filter != NTSCFilter::Preset::OFF)
      {
        // non-interlace square pixel clock -- 0.8 pixel @ color burst -- double-width pixels
        par = (7.3750000f / (4.43361875f * 4.0f / 5.0f)) / 2.0f;
      }
      else
      {
        // blargg filter
        par = 1.0;
      }
    }
    else
      par = video_aspect_pal / 100.0;
  }

  return par;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
float StellaLIBRETRO::getVideoAspect() const
{
  uInt32 width = myOSystem->console().tia().width() * 2;

  // display aspect ratio
  return (width * getVideoAspectPar()) / getVideoHeight();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void* StellaLIBRETRO::getVideoBuffer() const
{
  if (!render_surface)
  {
    const FBSurface& surface =
        myOSystem->frameBuffer().tiaSurface().tiaSurface();

    uInt32 pitch = 0;
    surface.basePtr(render_surface, pitch);
  }

  return render_surface;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StellaLIBRETRO::getVideoNTSC() const
{
  return myOSystem->console().gameRefreshRate() == 60;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StellaLIBRETRO::getVideoResize()
{
  if (render_width != getRenderWidth() || render_height != getRenderHeight())
  {
    render_width = getRenderWidth();
    render_height = getRenderHeight();

    return true;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::setROM(const char* path, const void* data, size_t size)
{
  rom_path = path;

  memcpy(rom_image.get(), data, size);

  rom_size = static_cast<uInt32>(size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::setConsoleFormat(uInt32 mode)
{
  switch(mode)
  {
    case 0:  console_format = "AUTO";    break;
    case 1:  console_format = "NTSC";    break;
    case 2:  console_format = "PAL";     break;
    case 3:  console_format = "SECAM";   break;
    case 4:  console_format = "NTSC50";  break;
    case 5:  console_format = "PAL60";   break;
    case 6:  console_format = "SECAM60"; break;
  }

  if (system_ready)
    myOSystem->settings().setValue("format", console_format);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::setVideoFilter(NTSCFilter::Preset mode)
{
  video_filter = mode;

  if (system_ready)
  {
    myOSystem->settings().setValue("tv.filter", static_cast<int>(mode));
    myOSystem->frameBuffer().tiaSurface().setNTSC(mode);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::setVideoPalette(const string& mode)
{
  if (system_ready)
  {
    myOSystem->settings().setValue("palette", video_palette);
    myOSystem->frameBuffer().tiaSurface().paletteHandler().setPalette(video_palette);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::setVideoPhosphor(uInt32 mode, uInt32 blend)
{
  switch (mode)
  {
    case 0:  video_phosphor = "byrom";  break;
    case 1:  video_phosphor = "never";  break;
    case 2:  video_phosphor = "always"; break;
  }

  video_phosphor_blend = blend;

  if (system_ready)
  {
    myOSystem->settings().setValue("tv.phosphor", video_phosphor);
    myOSystem->settings().setValue("tv.phosblend", blend);

    switch (mode)
    {
      case 0: myOSystem->frameBuffer().tiaSurface().enablePhosphor(phosphor_default, blend); break;
      case 1: myOSystem->frameBuffer().tiaSurface().enablePhosphor(false, blend); break;
      case 2: myOSystem->frameBuffer().tiaSurface().enablePhosphor(true, blend); break;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaLIBRETRO::setAudioStereo(int mode)
{
  switch (mode)
  {
    case 0:  audio_mode = "byrom";  break;
    case 1:  audio_mode = "mono";   break;
    case 2:  audio_mode = "stereo"; break;
  }

  if (system_ready)
  {
    myOSystem->settings().setValue(AudioSettings::SETTING_STEREO, audio_mode);
    myOSystem->console().initializeAudio();
  }
}
