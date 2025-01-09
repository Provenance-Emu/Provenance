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

#include "bspf.hxx"
#include "OSystem.hxx"
#include "Version.hxx"
#include "Logger.hxx"
#include "AudioSettings.hxx"
#include "TIASurface.hxx"
#include "PaletteHandler.hxx"
#include "Joystick.hxx"
#include "Paddles.hxx"
#ifdef GUI_SUPPORT
  #include "JitterEmulation.hxx"
#endif

#ifdef DEBUGGER_SUPPORT
  #include "DebuggerDialog.hxx"
#endif

//#if defined(BSPF_WINDOWS)
//#include <windows.hxx>
//#endif

#if defined(BSPF_UNIX) || defined(BSPF_MACOS)
#include <cstdio>
#include <sys/ioctl.h>
#include <unistd.h>
#endif

#include "Settings.hxx"
#include "repository/KeyValueRepositoryNoop.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Settings::Settings()
  : myRespository{make_shared<KeyValueRepositoryNoop>()}
{
  // If no version is recorded with the persisted settings, we set it to zero
  setPermanent(SETTINGS_VERSION_KEY, 0);
  setPermanent("stella.version", "6.2.1");

  //setTemporary("minimal_ui", 1); // enable for minimal UI testing only

  // Video-related options
  setPermanent("video", "");
  setPermanent("speed", "1.0");
  setPermanent("vsync", "true");
  setPermanent("center", "true");
  setPermanent("windowedpos", Common::Point(50, 50));
  setPermanent("display", 0);
  setPermanent("uimessages", "true");
  setPermanent("pausedim", "true");
  setPermanent("bezel.show", "true");
  setPermanent("bezel.windowed", "false");
  setPermanent("bezel.win.auto", "true");
  setPermanent("bezel.win.left", "12");
  setPermanent("bezel.win.right", "12");
  setPermanent("bezel.win.top", "0");
  setPermanent("bezel.win.bottom", "0");
  // TIA specific options
  setPermanent("tia.inter", "false");
  setPermanent("tia.zoom", "3");
  setPermanent("fullscreen", "false");
  setPermanent("tia.fs_stretch", "false");
  setPermanent("tia.fs_refresh", "false");
  setPermanent("tia.fs_overscan", "0");
  setPermanent("tia.vsizeadjust", 0);
  setPermanent("tia.dbgcolors", "roygpb");
  setPermanent("tia.correct_aspect", "true");
  // Palette options
  setPermanent("palette", PaletteHandler::SETTING_STANDARD);
  setPermanent("pal.phase_ntsc", "26.2");
  setPermanent("pal.phase_pal", "31.3");
  setPermanent("pal.red_scale", "0.0");
  setPermanent("pal.green_scale", "0.0");
  setPermanent("pal.blue_scale", "0.0");
  setPermanent("pal.red_shift", "0.0");
  setPermanent("pal.green_shift", "0.0");
  setPermanent("pal.blue_shift", "0.0");

  setPermanent("pal.contrast", "0.0");
  setPermanent("pal.brightness", "0.0");
  setPermanent("pal.hue", "0.0");
  setPermanent("pal.saturation", "0.0");
  setPermanent("pal.gamma", "0.0");
  // TV filtering options
  setPermanent("tv.filter", "0");
  setPermanent(PhosphorHandler::SETTING_MODE, PhosphorHandler::VALUE_BYROM);
  setPermanent(PhosphorHandler::SETTING_BLEND, PhosphorHandler::DEFAULT_BLEND);
  setPermanent("tv.scanlines", "0");
  setPermanent("tv.scanmask", TIASurface::SETTING_STANDARD);
  // TV options when using 'custom' mode
  setPermanent("tv.sharpness", "0.0");
  setPermanent("tv.resolution", "0.0");
  setPermanent("tv.artifacts", "0.0");
  setPermanent("tv.fringing", "0.0");
  setPermanent("tv.bleed", "0.0");

  setPermanent("detectpal60", "false");
  setPermanent("detectntsc50", "false");

  // Sound options
  setPermanent(AudioSettings::SETTING_ENABLED, AudioSettings::DEFAULT_ENABLED);
  setPermanent(AudioSettings::SETTING_VOLUME, AudioSettings::DEFAULT_VOLUME);
  setPermanent(AudioSettings::SETTING_DEVICE, AudioSettings::DEFAULT_DEVICE);
  setPermanent(AudioSettings::SETTING_PRESET, static_cast<int>(AudioSettings::DEFAULT_PRESET));
  setPermanent(AudioSettings::SETTING_FRAGMENT_SIZE, AudioSettings::DEFAULT_FRAGMENT_SIZE);
  setPermanent(AudioSettings::SETTING_SAMPLE_RATE, AudioSettings::DEFAULT_SAMPLE_RATE);
  setPermanent(AudioSettings::SETTING_RESAMPLING_QUALITY, static_cast<int>(AudioSettings::DEFAULT_RESAMPLING_QUALITY));
  setPermanent(AudioSettings::SETTING_HEADROOM, AudioSettings::DEFAULT_HEADROOM);
  setPermanent(AudioSettings::SETTING_BUFFER_SIZE, AudioSettings::DEFAULT_BUFFER_SIZE);
  setPermanent(AudioSettings::SETTING_STEREO, AudioSettings::DEFAULT_STEREO);
  setPermanent(AudioSettings::SETTING_DPC_PITCH, AudioSettings::DEFAULT_DPC_PITCH);

  // Input event options
  setPermanent("event_ver", "1");
  setPermanent("keymap_emu", "");
  setPermanent("keymap_joy", "");
  setPermanent("keymap_pad", "");
  setPermanent("keymap_drv", "");
  setPermanent("keymap_key", "");
  setPermanent("keymap_ui", "");
  setPermanent("joymap", "");
  setPermanent("combomap", "");
  setPermanent("joydeadzone", "13");
  setPermanent("joyallow4", "false");
  setPermanent("autofire", "0");
  setPermanent("autofirerate", "0");
  setPermanent("usemouse", "analog");
  setPermanent("grabmouse", "true");
  setPermanent("cursor", "2");
  setPermanent("adeadzone", "0");
  setPermanent("plinear", "100");
  setPermanent("dejitter.base", "0");
  setPermanent("dejitter.diff", "0");
  setPermanent("dsense", "10");
  setPermanent("psense", "20");
  setPermanent("msense", "10");
  setPermanent("tsense", "10");
  setPermanent("dcsense", "10");
  setPermanent("saport", "lr");
  setPermanent("modcombo", "true");

  // Snapshot options
  setPermanent("snapsavedir", "");
  setPermanent("snaploaddir", "");
  setPermanent("snapname", "int");
  setPermanent("sssingle", "false");
  setPermanent("ss1x", "false");
  setPermanent("ssinterval", "2");
  setPermanent("autoslot", "false");
  setPermanent("saveonexit", "none");

  // Config files and paths
  setPermanent("romdir", "");
  setPermanent("userdir", "");
  setPermanent("saveuserdir", "false");
  setPermanent("bezel.dir", "");

  // ROM browser options
  setPermanent("exitlauncher", "false");
  setPermanent("followlauncher", "false");
  setPermanent("launcherpos", Common::Point(50, 50));
  setPermanent("launcherdisplay", 0);
  setPermanent("launcherres", Common::Size(900, 600));
  setPermanent("launcherfont", "medium");
  setPermanent("launchersubdirs", "false");
  setPermanent("launcherextensions", "false");
  setPermanent("launcherbuttons", "false");
  setPermanent("romviewer", "1");
  setPermanent("lastrom", "");
  setPermanent("favorites", "true");
  setPermanent("_favoriteroms", "");  // internal only
  setPermanent("_recentroms", "");    // internal only
  setPermanent("maxrecentroms", "20");
  setPermanent("_popularroms", "");   // internal only
  setPermanent("altsorting", "false");

  // UI-related options
#ifdef DEBUGGER_SUPPORT
  setPermanent("dbg.res",
    Common::Size(DebuggerDialog::kMediumFontMinW,
                 DebuggerDialog::kMediumFontMinH));
  setPermanent("dbg.pos", Common::Point(50, 50));
  setPermanent("dbg.display", 0);
#endif
  setPermanent("uipalette", "standard");
  setPermanent("uipalette2", "dark");
  setPermanent("altuipalette", "false");
  setPermanent("hidpi", "false");
  setPermanent("listdelay", "300");
  setPermanent("mwheel", "4");
  setPermanent("mdouble", "500");
  setPermanent("ctrldelay", "400");
  setPermanent("ctrlrate", "20");
  setPermanent("basic_settings", false);
  setPermanent("dialogfont", "medium");
  setPermanent("dialogpos", 0);
  setPermanent("confirmexit", false);
  setPermanent("autopause", false);

  // Misc options
  setPermanent("loglevel", static_cast<int>(Logger::Level::INFO));
  setPermanent("logtoconsole", "0");
  setPermanent("avoxport", "");
  setPermanent("fastscbios", "true");
  setPermanent("threads", "false");
  setTemporary("romloadcount", "0");
  setTemporary("maxres", "");
  setPermanent("initials", "");
  setTemporary("turbo", "0");
  setPermanent("plusroms.nick", "");
  setTemporary("plusroms.id", "");
  setPermanent("plusroms.fixedid", "");
  setPermanent("filterbstypes", "true");

#ifdef DEBUGGER_SUPPORT
  // Debugger/disassembly options
  setPermanent("dbg.fontsize", "medium");
  setPermanent("dbg.fontstyle", "0");
  setPermanent("dbg.uhex", "false");
  setPermanent("dbg.ghostreadstrap", "true");
  setPermanent("dbg.logbreaks", "false");
  setPermanent("dbg.logtrace", "false");
  setPermanent("dbg.autosave", "false");
  setPermanent("dis.resolve", "true");
  setPermanent("dis.gfxformat", "2");
  setPermanent("dis.showaddr", "true");
  setPermanent("dis.relocate", "false");
  setPermanent("dev.rwportbreak", "true");
  setPermanent("dev.wrportbreak", "true");
#endif

  // Player settings
  setPermanent("plr.stats", "false");
  setPermanent("plr.bankrandom", "false");
  setPermanent("plr.ramrandom", "true");
  setPermanent("plr.cpurandom", "AXYP");
  setPermanent("plr.tiarandom", "false");
  setPermanent("plr.colorloss", "false");
#ifdef GUI_SUPPORT
  setPermanent("plr.tv.jitter", "true");
  setPermanent("plr.tv.jitter_sense", JitterEmulation::PLR_SENSITIVITY);
  setPermanent("plr.tv.jitter_recovery", JitterEmulation::PLR_RECOVERY);
#else
  setPermanent("plr.tv.jitter", "false");
  setPermanent("plr.tv.jitter_sense", 1);
  setPermanent("plr.tv.jitter_recovery", 1);
#endif
  setPermanent("plr.debugcolors", "false");
  setPermanent("plr.console", "2600"); // 7800
  setPermanent("plr.timemachine", true);
  setPermanent("plr.tm.size", 200);
  setPermanent("plr.tm.uncompressed", 60);
  setPermanent("plr.tm.interval", "30f"); // = 0.5 seconds
  setPermanent("plr.tm.horizon", "10m"); // = ~10 minutes
  setPermanent("plr.detectedinfo", "false");
  setPermanent("plr.extaccess", "false");

  // Developer settings
  setPermanent("dev.settings", "false");
  setPermanent("dev.stats", "true");
  setPermanent("dev.bankrandom", "true");
  setPermanent("dev.ramrandom", "true");
  setPermanent("dev.cpurandom", "SAXYP");
  setPermanent("dev.tiarandom", "true");
  setPermanent("dev.hsrandom", "true");
  setPermanent("dev.colorloss", "true");
#ifdef GUI_SUPPORT
  setPermanent("dev.tv.jitter", "true");
  setPermanent("dev.tv.jitter_sense", JitterEmulation::DEV_SENSITIVITY);
  setPermanent("dev.tv.jitter_recovery", JitterEmulation::DEV_RECOVERY);
#else
  setPermanent("dev.tv.jitter", "false");
  setPermanent("dev.tv.jitter_sense", 1);
  setPermanent("dev.tv.jitter_recovery", 1);
#endif
  setPermanent("dev.debugcolors", "false");
  setPermanent("dev.tiadriven", "true");
  setPermanent("dev.console", "2600"); // 7800
  setPermanent("dev.tia.type", "standard");
  setPermanent("dev.tia.plinvphase", "true");
  setPermanent("dev.tia.msinvphase", "true");
  setPermanent("dev.tia.blinvphase", "true");
  setPermanent("dev.tia.delaypfbits", "true");
  setPermanent("dev.tia.delaypfcolor", "true");
  setPermanent("dev.tia.pfscoreglitch", "true");
  setPermanent("dev.tia.delaybkcolor", "true");
  setPermanent("dev.tia.delayplswap", "true");
  setPermanent("dev.tia.delayblswap", "true");
  setPermanent("dev.timemachine", true);
  setPermanent("dev.tm.size", 1000);
  setPermanent("dev.tm.uncompressed", 600);
  setPermanent("dev.tm.interval", "1f"); // = 1 frame
  setPermanent("dev.tm.horizon", "30s"); // = ~30 seconds
  setPermanent("dev.detectedinfo", "true");
  setPermanent("dev.extaccess", "true");
  // Thumb ARM emulation options
  setPermanent("dev.thumb.trapfatal", "true");
#ifdef DEBUGGER_SUPPORT
  setPermanent("dev.thumb.inccycles", "true");
  setPermanent("dev.thumb.cyclefactor", "1.05");
  setPermanent("dev.thumb.chiptype", "0"); // = LPC2103
  setPermanent("dev.thumb.mammode", "2");
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::setRepository(shared_ptr<KeyValueRepository> repository)
{
  myRespository = std::move(repository);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::load(const Options& options)
{
  const Options fromFile = myRespository->load();
  for (const auto& opt: fromFile)
    setValue(opt.first, opt.second, false);

  migrate();

  // Apply commandline options, which override those from settings file
  for(const auto& opt: options)
    setValue(opt.first, opt.second, false);

  // Finally, validate some settings, so the rest of the codebase
  // can assume the values are valid
  validate();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::save()
{
  myRespository->save(myPermanentSettings);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::validate()
{
  const float f = getFloat("speed");
  if (f <= 0) setValue("speed", "1.0");

  int i = getInt("tia.vsizeadjust");
  if(i < -5 || i > 5)  setValue("tia.vsizeadjust", 0);

  string s = getString("tia.dbgcolors");
  sort(s.begin(), s.end());
  if(s != "bgopry")  setValue("tia.dbgcolors", "roygpb");

  if(PhosphorHandler::toPhosphorMode(getString(PhosphorHandler::SETTING_MODE)) == PhosphorHandler::ByRom)
    setValue(PhosphorHandler::SETTING_MODE, PhosphorHandler::VALUE_BYROM);

  i = getInt(PhosphorHandler::SETTING_BLEND);
  if(i < 0 || i > 100)
    setValue(PhosphorHandler::SETTING_BLEND, PhosphorHandler::DEFAULT_BLEND);

  s = getString("tv.scanmask");
  if(s != TIASurface::SETTING_STANDARD
      && s != TIASurface::SETTING_THIN
      && s != TIASurface::SETTING_PIXELS
      && s != TIASurface::SETTING_APERTURE
      && s != TIASurface::SETTING_MAME)
    setValue("tv.scanmask", TIASurface::SETTING_STANDARD);

  i = getInt("tv.filter");
  if(i < 0 || i > 5)  setValue("tv.filter", "0");

#ifdef GUI_SUPPORT
  i = getInt("dev.tv.jitter_sense");
  if(i < JitterEmulation::MIN_SENSITIVITY || i > JitterEmulation::MAX_SENSITIVITY)
    setValue("dev.tv.jitter_sense", JitterEmulation::DEV_SENSITIVITY);

  i = getInt("dev.tv.jitter_recovery");
  if(i < JitterEmulation::MIN_RECOVERY || i > JitterEmulation::MAX_RECOVERY)
    setValue("dev.tv.jitter_recovery", JitterEmulation::DEV_RECOVERY);
#endif

  int size = getInt("dev.tm.size");
  if(size < 20 || size > 1000)
  {
    setValue("dev.tm.size", 20);
    size = 20;
  }

  i = getInt("dev.tm.uncompressed");
  if(i < 0 || i > size) setValue("dev.tm.uncompressed", size);

  /*i = getInt("dev.tm.interval");
  if(i < 0 || i > 5) setValue("dev.tm.interval", 0);

  i = getInt("dev.tm.horizon");
  if(i < 0 || i > 6) setValue("dev.tm.horizon", 1);*/

#ifdef GUI_SUPPORT
  i = getInt("plr.tv.jitter_sense");
  if(i < JitterEmulation::MIN_SENSITIVITY || i > JitterEmulation::MAX_SENSITIVITY)
    setValue("plr.tv.jitter_sense", JitterEmulation::PLR_SENSITIVITY);

  i = getInt("plr.tv.jitter_recovery");
  if(i < 1 || i > 20) setValue("plr.tv.jitter_recovery", JitterEmulation::PLR_RECOVERY);
#endif

  size = getInt("plr.tm.size");
  if(size < 20 || size > 1000)
  {
    setValue("plr.tm.size", 20);
    size = 20;
  }

  i = getInt("plr.tm.uncompressed");
  if(i < 0 || i > size) setValue("plr.tm.uncompressed", size);

  /*i = getInt("plr.tm.interval");
  if(i < 0 || i > 5) setValue("plr.tm.interval", 3);

  i = getInt("plr.tm.horizon");
  if(i < 0 || i > 6) setValue("plr.tm.horizon", 5);*/

#ifdef SOUND_SUPPORT
  AudioSettings::normalize(*this);
#endif

  setValue("joydeadzone", BSPF::clamp(getInt("joydeadzone"),
           Controller::MIN_DIGITAL_DEADZONE, Joystick::MAX_DIGITAL_DEADZONE));

  setValue("adeadzone", BSPF::clamp(getInt("adeadzone"),
           Controller::MIN_ANALOG_DEADZONE, Controller::MAX_ANALOG_DEADZONE));

  setValue("psense", BSPF::clamp(getInt("psense"),
           Paddles::MIN_ANALOG_SENSE, Paddles::MAX_ANALOG_SENSE));

  setValue("plinear", BSPF::clamp(getInt("plinear"),
           Paddles::MIN_ANALOG_LINEARITY, Paddles::MAX_ANALOG_LINEARITY));

  setValue("dejitter.base", BSPF::clamp(getInt("dejitter.base"),
           Paddles::MIN_DEJITTER, Paddles::MAX_DEJITTER));

  setValue("dejitter.diff", BSPF::clamp(getInt("dejitter.diff"),
           Paddles::MIN_DEJITTER, Paddles::MAX_DEJITTER));

  setValue("dsense", BSPF::clamp(getInt("dsense"),
           Paddles::MIN_DIGITAL_SENSE, Paddles::MAX_DIGITAL_SENSE));

  setValue("msense", BSPF::clamp(getInt("msense"),
           Controller::MIN_MOUSE_SENSE, Controller::MAX_MOUSE_SENSE));

  i = getInt("cursor");
  if(i < 0 || i > 3)
    setValue("cursor", "2");

  i = getInt("tsense");
  if(i < 1 || i > 20)
    setValue("tsense", "10");

  i = getInt("dcsense");
  if(i < 1 || i > 20)
    setValue("dcsense", "10");

  i = getInt("ssinterval");
  if(i < 1)        setValue("ssinterval", "2");
  else if(i > 10)  setValue("ssinterval", "10");

  s = getString("palette");
  if(s != PaletteHandler::SETTING_STANDARD
     && s != PaletteHandler::SETTING_Z26
     && s != PaletteHandler::SETTING_USER
     && s != PaletteHandler::SETTING_CUSTOM)
    setValue("palette", PaletteHandler::SETTING_STANDARD);

  s = getString("launcherfont");
  if(s != "small" && s != "low_medium" && s != "medium" && s != "large"
     && s != "large12" && s != "large14" && s != "large16")
    setValue("launcherfont", "medium");

  s = getString("dbg.fontsize");
  if(s != "small" && s != "medium" && s != "large")
    setValue("dbg.fontsize", "medium");

  i = getInt("romviewer");
  if(i < 0) setValue("romviewer", "0");

  i = getInt("loglevel");
  if(i < static_cast<int>(Logger::Level::MIN) || i > static_cast<int>(Logger::Level::MAX))
    setValue("loglevel", static_cast<int>(Logger::Level::INFO));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::usage()
{
  stringstream buf;
  buf << "\nStella version " << STELLA_VERSION
    << "\n\n"
    << "Usage: stella [options ...] romfile\n"
    << "       Run without any options or romfile to use the ROM launcher\n"
    << "       Consult the manual for more in-depth information\n\n"
    << "Valid options are:\n\n"
    << "  -video        <type>         Type is one of the following:\n"
  #ifdef BSPF_WINDOWS
    << "                 direct3d        Direct3D acceleration\n"
  #endif
    << "                 opengl          OpenGL acceleration\n"
    << "                 opengles2       OpenGLES 2 acceleration\n"
    << "                 opengles        OpenGLES 1 acceleration\n"
    << "                 software        Software mode (no acceleration)\n\n"
    << "  -vsync        <1|0>          Enable 'synchronize to vertical blank interrupt'\n"
    << "  -fullscreen   <1|0>          Enable fullscreen mode\n"
    << "  -center       <1|0>          Centers game window in windowed modes\n"
    << "  -windowedpos  <XxY>          Sets the window position in windowed emulator mode\n"
    << "  -display      <number>       Sets the display for Stella's emulator\n\n"
    << "  -palette        <standard|     Use the specified color palette\n"
    << "                   z26|user|\n"
    << "                   custom>\n"
    << "  -pal.phase_ntsc  <number>      Phase shift for NTSC 'custom' palette\n"
    << "  -pal.phase_pal   <number>      Phase shift for PAL 'custom' palette\n"
    << "  -pal.red_scale   <-1.0 - 1.0>  Adjust red scale for 'custom' palette\n"
    << "  -pal.red_shift   <-1.0 - 1.0>  Adjust red shift for 'custom' palette\n"
    << "  -pal.green_scale <-1.0 - 1.0>  Adjust green scale for 'custom' palette\n"
    << "  -pal.green_shift <-1.0 - 1.0>  Adjust green shift for 'custom' palette\n"
    << "  -pal.blue_scale  <-1.0 - 1.0>  Adjust blue scale for 'custom' palette\n"
    << "  -pal.blue_shift  <-1.0 - 1.0>  Adjust blue shift for 'custom' palette\n"
    << "  -pal.hue         <-1.0 - 1.0>  Adjust hue for current palette\n"
    << "  -pal.saturation  <-1.0 - 1.0>  Adjust saturation of current palette\n"
    << "  -pal.contrast    <-1.0 - 1.0>  Adjust contrast of current palette\n"
    << "  -pal.brightness  <-1.0 - 1.0>  Adjust brightness of current palette\n"
    << "  -pal.gamma       <-1.0 - 1.0>  Adjust gamma of current palette\n\n"
    << "  -detectpal60     <1|0>         Enable PAL-60 autodetection\n"
    << "  -detectntsc50    <1|0>         Enable NTSC-50 autodetection\n\n"
    << "  -speed           <number>      Run emulation at the given speed\n"
    << "  -turbo           <1|0>         Enable 'Turbo' mode for maximum emulation speed\n"
    << "  -uimessages      <1|0>         Show onscreen UI messages for different events\n"
    << "  -pausedim        <1|0>         Enable emulation dimming in pause mode\n\n"
    << "  -bezel.show        <1|0>       Show bezel around emulation window\n"
    << "  -bezel.windowed    <1|0>       Show bezel in windowed modes\n"
    << "  -bezel.win.auto    <1|0>       Automatically set bezel window position\n"
    << "  -bezel.win.left    <0-40>      Set left bezel window position [%]\n"
    << "  -bezel.win.right   <0-40>      Set right bezel window position [%]\n"
    << "  -bezel.win.top     <0-40>      Set top bezel window position [%]\n"
    << "  -bezel.win.bottom  <0-40>      Set bottom bezel window position [%]\n\n"
  #ifdef SOUND_SUPPORT
    << "  -audio.enabled            <1|0>      Enable audio\n"
    << "  -audio.volume             <0-100>    Volume\n"
    << "  -audio.device             <number>   ID of the audio device (0 = default)\n"
    << "  -audio.preset             <1-5>      Audio preset (or 1 for custom)\n"
    << "  -audio.sample_rate        <number>   Output sample rate (44100|48000|96000)\n"
    << "  -audio.fragment_size      <number>   Fragment size (128|256|512|1024|\n"
    << "                                        2048|4096)\n"
    << "  -audio.resampling_quality <1-3>      Resampling quality\n"
    << "  -audio.headroom           <0-20>     Additional half-frames to prebuffer\n"
    << "  -audio.buffer_size        <0-20>     Max. number of additional half-\n"
    << "                                        frames to buffer\n"
    << "  -audio.stereo             <1|0>      Enable stereo mode for all ROMs\n\n"
  #endif
    << "  -tia.zoom        <zoom>       Use the specified zoom level (windowed mode)\n"
    << "                                 for TIA image\n"
    << "  -tia.vsizeadjust <-5..5>      Adjust the vertical display size [percent]\n"
    << "  -tia.inter       <1|0>        Enable interpolated (smooth) scaling for TIA\n"
    << "                                 image\n"
    << "  -tia.fs_stretch  <1|0>        Stretch TIA image to fill fullscreen mode\n"
    << "  -tia.fs_refresh  <1|0>        Try to adapt display refresh rate to game's FPS\n"
    << "  -tia.fs_overscan <0-10>       Add overscan to TIA image in fullscreen mode\n"
    << "  -tia.dbgcolors   <string>     Debug colors to use for each object (see manual\n"
    << "                                 for description)\n"
    << "  -tia.correct_aspect <1|0>     Enable aspect ratio correct scaling\n\n"
    << "  -tv.filter    <0-5>           Set TV effects off (0) or to specified mode\n"
    << "                                 (1-5)\n"
    << "  -tv.phosphor  <byrom|always|> When to use phosphor mode\n"
    << "                 autoon|auto\n"
    << "  -tv.phosblend <0-100>         Set default blend level in phosphor mode\n"
    << "  -tv.scanlines <0-100>         Set scanline intensity to percentage\n"
    << "                                 (0 disables completely)\n"
    << "  -tv.scanmask  <standard|      Use the specified scanline mask\n"
    << "                 thin|pixel|\n"
    << "                 mame>\n"
    << "  -tv.sharpness   <-1.0 - 1.0>  Set TV effects custom sharpness\n"
    << "  -tv.resolution  <-1.0 - 1.0>  Set TV effects custom resolution\n"
    << "  -tv.artifacts   <-1.0 - 1.0>  Set TV effects custom artifacts\n"
    << "  -tv.fringing    <-1.0 - 1.0>  Set TV effects custom fringing\n"
    << "  -tv.bleed       <-1.0 - 1.0>  Set TV effects custom bleed\n\n"
    << "  -cheat        <code>         Use the specified cheatcode (see manual for\n"
    << "                                description)\n"
    << "  -loglevel     <0|1|2>        Set level of logging during application run\n\n"
    << "  -logtoconsole <1|0>          Log output to console/commandline\n"
    << "  -joydeadzone  <0-29>         Sets digital 'dead zone' area for analog joysticks\n"
    << "  -joyallow4    <1|0>          Allow all 4 directions on a joystick to be\n"
    << "                                pressed simultaneously\n"
    << "  -usemouse     <always|\n"
    << "                 analog|\n"
    << "                 never>        Use mouse as a controller as specified by ROM\n"
    << "                                properties in given mode(see manual)\n"
    << "  -grabmouse      <1|0>        Locks the mouse cursor in the TIA window\n"
    << "  -cursor         <0,1,2,3>    Set cursor state in UI/emulation modes\n"
    << "  -adeadzone      <0-29>       Sets analog 'dead zone' area for analog joysticks\n"
    << "  -plinear        <25-100>     Sets paddle linearity\n"
    << "  -dejitter.base  <0-10>       Strength of analog paddle value averaging\n"
    << "  -dejitter.diff  <0-10>       Strength of analog paddle reaction to fast movements\n"
    << "  -psense         <0-30>       Sensitivity of analog paddle movement\n"
    << "  -dsense         <1-20>       Sensitivity of digital emulated paddle movement\n"
    << "  -msense         <1-20>       Sensitivity of mouse emulated paddle movement\n"
    << "  -tsense         <1-20>       Sensitivity of mouse emulated trackball movement\n"
    << "  -dcsense        <1-20>       Sensitivity of digital emulated driving controller\n"
    << "                                movement\n"
    << "  -autofire     <1|0>          Enable fire button autofire\n"
    << "  -autofirerate <0-30>         Set fire button's autofire rate (0 means off)\n"
    << "  -saport       <lr|rl>        How to assign virtual ports to multiple\n"
    << "                                Stelladaptor/2600-daptors\n"
    << "  -modcombo     <1|0>          Enable modifier key combos\n"
    << "                                (Control-Q for quit may not work when disabled!)\n"
    << "  -fastscbios   <1|0>          Disable Supercharger BIOS progress loading bars\n"
    << "  -threads      <1|0>          Whether to using multi-threading during\n"
    << "                                emulation\n"
    << "  -snapsavedir  <path>         The directory to save snapshot files to\n"
    << "  -snaploaddir  <path>         The directory to load snapshot files from\n"
    << "  -snapname     <int|rom>      Name snapshots according to internal database or\n"
    << "                                ROM\n"
    << "  -sssingle     <1|0>          Generate single snapshot instead of many\n"
    << "  -ss1x         <1|0>          Generate TIA snapshot in 1x mode (ignore\n"
    << "                                scaling/effects)\n"
    << "  -ssinterval   <number>       Number of seconds between snapshots in\n"
    << "                                continuous snapshot mode\n\n"
    << "  -saveonexit   <none|current| Automatically save state(s) when exiting\n"
    << "                 all>           emulation\n"
    << "  -autoslot     <0|1>          Automatically change to next save slot when\n"
    << "                                state saving\n\n"
    << "  -rominfo      <rom>          Display detailed information for the given ROM\n"
    << "  -listrominfo                 Display contents of stella.pro, one line per ROM\n"
    << "                                entry\n\n"
    << "  -exitlauncher <0|1>          On exiting a ROM, go back to the ROM launcher\n"
    << "  -launcherpos  <XxY>          Sets the window position in windowed launcher\n"
    << "                                mode\n"
    << "  -launcherdisplay <number>    Sets the display for the ROM launcher\n"
    << "  -launcherres  <WxH>          The resolution to use in ROM launcher mode\n"
    << "  -launcherfont <small|        Use the specified font in the ROM launcher\n"
    << "                 low_medium|\n"
    << "                 medium|large|\n"
    << "                 large12|large14|\n"
    << "                 large16>\n"
    << "  -romviewer    <float>        Show ROM info viewer at given zoom level in ROM\n"
    << "                                launcher (use 0 for off)\n"
    << "  -launchersubdirs    <0|1>    Show files from subdirectories too\n"
    << "  -launcherextensions <0|1>    Display file extensions in launcher\n"
    << "  -launcherbuttons    <0|1>    Display bottom buttons in launcher\n"
    << "  -favorites          <0|1>    Enable virtual favorite directories in launcher\n"
    << "  -altsorting         <0|1>    Alternative sorting in virtual folders\n"
    << "  -maxrecentroms      <number> Number of ROMs tracked in 'Recently played'\n"
    << "  -romdir             <dir>    Set the path where the ROM launcher will start\n"
    << "  -followlauncher     <0|1>    Default ROM path follows launcher navigation\n"
    << "  -userdir            <dir>    Set the path to save user files to\n"
    << "  -saveuserdir        <0|1>    Update user path when navigating in browser\n"
    << "  -bezel.dir          <dir>    Set the path to load bezels from\n"
    << "  -lastrom            <name>   Last played ROM, automatically selected in\n"
    << "                                launcher\n"
    << "  -romloadcount <number>       Number of ROM to load next from multicard\n"
    << "  -uipalette    <standard|     Set GUI theme\n"
    << "                 classic|\n"
    << "                 light|dark>\n"
    << "  -uipalette2   <standard|     Set alternative GUI theme\n"
    << "                 classic|\n"
    << "                 light|dark>\n"
    << "  -altuipalette <0|1>          Enable alternative GUI theme\n"
    << "  -hidpi        <0|1>          Enable HiDPI mode\n"
    << "  -dialogfont   <small|        Use the specified font in the dialogs\n"
    << "                 low_medium|\n"
    << "                 medium|large|\n"
    << "                 large12|large14|\n"
    << "                 large16>\n"
    << "  -dialogpos    <0..4>         Display all dialogs at given positions\n"
    << "  -confirmexit  <0|1>          Display a confirm dialog when exiting emulation\n"
    << "  -autopause    <0|1>          Pause/continue emulation when focus is lost/gained\n"
    << "  -listdelay    <delay>        Time to wait between keypresses in list widgets\n"
    << "                                (300-1000)\n"
    << "  -mwheel       <lines>        Number of lines the mouse wheel will scroll in\n"
    << "                                UI\n"
    << "  -mdouble      <speed>        Mouse double click speed in UI\n"
    << "  -ctrldelay    <delay>        Delay before controller input is repeated in UI\n"
    << "  -ctrlrate     <rate>         Rate per second of repeated controller input in\n"
    << "                                UI\n"
    << "  -basic_settings <0|1>        Display only a basic settings dialog\n"
    << "  -avoxport     <name>         The name of the serial port where an AtariVox is\n"
    << "                                connected\n"
    << "  -holdreset                   Start the emulator with the Game Reset switch\n"
    << "                                held down\n"
    << "  -holdselect                  Start the emulator with the Game Select switch\n"
    << "                                held down\n"
    << "  -holdjoy0     <U,D,L,R,F>    Start the emulator with the left joystick\n"
    << "                                direction/fire button held down\n"
    << "  -holdjoy1     <U,D,L,R,F>    Start the emulator with the right joystick\n"
    << "                                direction/fire button held down\n"
    << "  -maxres       <WxH>          Used by developers to force the maximum size of\n"
    << "                                the application window\n"
    << "  -basedir  <path>             Override the base directory for all config files\n"
    << "  -baseinappdir                Override the base directory for all config files\n"
    << "                                by attempting to use the application directory\n"
    << "  -plusroms.nick <nick>        Define a nickname for the PlusROMs backends.\n"
    << "  -plusroms.id   <id>          Define a temporary ID for the PlusROMs backends.\n"
    << "  -filterbstypes <0|1>         Filter bankswitch type list by ROM size.\n"
    << "  -help                        Show the text you're now reading\n"
  #ifdef DEBUGGER_SUPPORT
    << "\n The following options are meant for developers\n"
    << " Arguments are more fully explained in the manual\n\n"
    << "   -dis.resolve   <1|0>        Attempt to resolve code sections in disassembler\n"
    << "   -dis.gfxformat <2|16>       Set base to use for displaying (P)GFX sections\n"
    << "                                in disassembler\n"
    << "   -dis.showaddr  <1|0>        Show opcode addresses in disassembler\n"
    << "   -dis.relocate  <1|0>        Relocate calls out of address range in\n"
    << "                                disassembler\n\n"
    << "   -dbg.pos       <XxY>          Sets the window position in windowed debugger mode\n"
    << "   -dbg.display   <number>       Sets the display for the debugger\n"
    << "   -dbg.res       <WxH>          The resolution to use in debugger mode\n"
    << "   -dbg.fontsize  <small|medium| Font size to use in debugger window\n"
    << "                  large>\n"
    << "   -dbg.fontstyle <0-3>          Font style to use in debugger window (bold vs.\n"
    << "                                  normal)\n"
    << "   -dbg.ghostreadstrap <1|0>     Debugger traps on 'ghost' reads\n"
    << "   -dbg.uhex      <0|1>          Lower-/uppercase HEX display\n"
    << "   -dbg.logbreaks <0|1>          Log breaks and traps and continue emulation\n"
    << "   -dbg.logtrace  <0|1>          Log emulation\n"
    << "   -dbg.autosave  <0|1>          Automatically save breaks, traps etc.\n"
    << "   -break         <address>      Set a breakpoint at 'address'\n"
    << "   -debug                        Start in debugger mode\n\n"
    << "   -bs          <arg>          Sets the 'Cartridge.Type' (bankswitch) property\n"
    << "   -type        <arg>          Same as using -bs\n"
    << "   -startbank   <bank>         Sets the ROM's startup bank\n"
    << "   -channels    <arg>          Sets the 'Cartridge.Sound' property\n"
    << "   -ld          <arg>          Sets the 'Console.LeftDifficulty' property\n"
    << "   -rd          <arg>          Sets the 'Console.RightDifficulty' property\n"
    << "   -tv          <arg>          Sets the 'Console.TelevisionType' property\n"
    << "   -sp          <arg>          Sets the 'Console.SwapPorts' property\n"
    << "   -lc          <arg>          Sets the 'Controller.Left' property\n"
    << "   -rc          <arg>          Sets the 'Controller.Right' property\n"
    << "   -bc          <arg>          Same as using both -lc and -rc\n"
    << "   -cp          <arg>          Sets the 'Controller.SwapPaddles' property\n"
    << "   -pxcenter    <arg>          Sets the 'Controller.PaddlesXCenter' property\n"
    << "   -pycenter    <arg>          Sets the 'Controller.PaddlesYCenter' property\n"
    << "   -format      <arg>          Sets the 'Display.Format' property\n"
    << "   -vcenter     <arg>          Sets the 'Display.vcenter' property\n"
    << "   -pp          <arg>          Sets the 'Display.Phosphor' property\n"
    << "   -ppblend     <arg>          Sets the 'Display.PPBlend' property\n"
    << "   -bezelname   <arg>          Sets the 'Bezel.Name' property\n\n"
  #endif

    << " Various development related parameters for player settings mode\n\n"
    << "  -dev.settings     <1|0>          Select developer (1) or player (0) settings\n"
    << "                                    mode\n\n"
    << "  -plr.stats        <1|0>          Overlay console info during emulation\n"
    << "  -plr.detectedinfo <1|0>          Enable initial detected settings info\n"
    << "  -plr.console      <2600|7800>    Select console for B/W and Pause key\n"
    << "                                    handling and RAM initialization\n"
    << "  -plr.bankrandom   <1|0>          Randomize the startup bank on reset\n"
    << "  -plr.ramrandom    <1|0>          Randomize the contents of RAM on reset\n"
    << "  -plr.tiarandom    <1|0>          Randomize the TIA registers on reset\n"
    << "  -plr.ramrandom    <1|0>          Randomize the contents of RAM on reset\n"
    << "  -plr.debugcolors  <1|0>          Enable debug colors\n"
    << "  -plr.colorloss    <1|0>          Enable PAL color-loss effect\n"
    << "  -plr.tv.jitter    <1|0>          Enable TV jitter effect\n"
    << "  -plr.tv.jitter_sense <1-10>      Set TV jitter effect sensitivity\n"
    << "  -plr.tv.jitter_recovery <1-20>   Set recovery time for TV jitter effect\n"
    << "  -plr.extaccess    <1|0>          Enable messages for external access\n\n"
    << " The same parameters but for developer settings mode\n"
    << "  -dev.stats        <1|0>          Overlay console info during emulation\n"
    << "  -dev.detectedinfo <1|0>          Enable initial detected settings info\n"
    << "  -dev.console      <2600|7800>    Select console for B/W and Pause key\n"
    << "                                    handling and RAM initialization\n"
    << "  -dev.bankrandom   <1|0>          Randomize the startup bank on reset\n"
    << "  -dev.ramrandom    <1|0>          Randomize the contents of RAM on reset\n"
    << "  -dev.cpurandom    <1|0>          Randomize the contents of CPU registers on\n"
    << "                                    reset\n"
    << "  -dev.tiarandom    <1|0>          Randomize the TIA registers on reset\n"
    << "  -dev.debugcolors  <1|0>          Enable debug colors\n"
    << "  -dev.colorloss    <1|0>          Enable PAL color-loss effect\n"
    << "  -dev.tv.jitter    <1|0>          Enable TV jitter effect\n"
    << "  -dev.tv.jitter_sense <1-10>      Set TV jitter effect sensitivity\n"
    << "  -dev.tv.jitter_recovery <1-20>   Set recovery time for TV jitter effect\n"
    << "  -dev.hsrandom     <1|0>          Randomize the hotspot peek values\n"
    << "  -dev.tiadriven    <1|0>          Drive unqused TIA pins randomly on a\n"
    << "                                    read/peek\n"
#ifdef DEBUGGER_SUPPORT
    << "  -dev.rwportbreak       <1|0>     Debugger breaks on reads from write ports\n"
    << "  -dev.wrportbreak       <1|0>     Debugger breaks on writes to read ports\n"
#endif
    << "  -dev.thumb.trapfatal   <1|0>     Determines whether errors in ARM emulation\n"
    << "                                    throw an exception\n"
#ifdef DEBUGGER_SUPPORT
    << "  -dev.thumb.inccycles   <1|0>     Determines whether ARM emulation cycles\n"
    << "                                    increase system cycles\n"
    << "  -dev.thumb.cyclefactor <float>   Sets the ARM cycles correction multiplier\n"
    << "  -dev.thumb.chiptype    <0|1>     Selects the ARM chip type\n"
    << "  -dev.thumb.mammode     <0-3>     Selects the LPC's MAM mode\n"
#endif
    << "  -dev.extaccess         <1|0>     Enable messages for external access\n"
    << "  -dev.tia.type <standard|custom|  Selects a TIA type\n"
    << "                 koolaidman|\n"
    << "                 cosmicark|pesco|\n"
    << "                 quickstep|matchie|\n"
    << "                 indy500|heman|>\n"
    << "  -dev.tia.plinvphase    <1|0>      Enable inverted HMOVE clock phase for players\n"
    << "  -dev.tia.msinvphase    <1|0>      Enable inverted HMOVE clock phase for\n"
    << "                                    missiles\n"
    << "  -dev.tia.blinvphase    <1|0>      Enable inverted HMOVE clock phase for ball\n"
    << "  -dev.tia.delaypfbits   <1|0>      Enable extra delay cycle for PF bits access\n"
    << "  -dev.tia.delaypfcolor  <1|0>      Enable extra delay cycle for PF color\n"
    << "  -dev.tia.pfscoreglitch <1|0>      Enable PF score mode color glitch\n"
    << "  -dev.tia.delaybkcolor  <1|0>      Enable extra delay cycle for background color\n"
    << "  -dev.tia.delayplswap   <1|0>      Enable extra delay cycle for VDELP0/1 swap\n"
    << "  -dev.tia.delayblswap   <1|0>      Enable extra delay cycle for VDELBL swap\n\n";

#ifdef BSPF_WINDOWS
//  int height = 25;
//  CONSOLE_SCREEN_BUFFER_INFO csbi;
//
//  if(NULL != GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi))
//    height = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
  cout << buf.str() << std::flush;
#endif

#if defined(BSPF_UNIX) || defined(BSPF_MACOS)
  int height = 25;
  struct winsize ws;

  ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws);

  height = ws.ws_row;

  int row = 0;
  while(buf.good())
  {
    if(++row == height - 1)
    {
      row = 0;
      cout << "Press \"Enter\"" << std::flush;
      std::ignore = getchar();
      cout << '\n';
    }
    string substr;
    getline(buf, substr, '\n');
    cout << substr << '\n';
  }
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Variant& Settings::value(string_view key) const
{
  // Try to find the named setting and answer its value
  auto it = myPermanentSettings.find(key);
  if(it != myPermanentSettings.end())
    return it->second;
  else
  {
    it = myTemporarySettings.find(key);
    if(it != myTemporarySettings.end())
      return it->second;
  }
  return EmptyVariant;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::setValue(string_view key, const Variant& value, bool persist)
{
  const auto it = myPermanentSettings.find(key);

  if(it != myPermanentSettings.end()) {
    if (persist && it->second != value && myRespository->atomic())
      myRespository->atomic()->save(key, value);
    it->second = value;
  }
  else
    myTemporarySettings[string{key}] = value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::setPermanent(string_view key, const Variant& value)
{
  myPermanentSettings[string{key}] = value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::setTemporary(string_view key, const Variant& value)
{
  myTemporarySettings[string{key}] = value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::migrateOne()
{
  const int version = getInt(SETTINGS_VERSION_KEY);
  if (version >= SETTINGS_VERSION) return;

  switch (version) {  // NOLINT  (could be written as IF/ELSE)
    case 0:
      #if defined BSPF_MACOS || defined DARWIN
        setPermanent("video", "");
      #endif
      break;
    default:
      break;
  }

  setPermanent(SETTINGS_VERSION_KEY, version + 1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Settings::migrate()
{
  while (getInt(SETTINGS_VERSION_KEY) < SETTINGS_VERSION) migrateOne();

  if (myRespository->atomic())
    myRespository->atomic()->save(SETTINGS_VERSION_KEY, SETTINGS_VERSION);
}
