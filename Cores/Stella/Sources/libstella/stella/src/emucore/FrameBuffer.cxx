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
#include "Logger.hxx"

#include "Console.hxx"
#include "EventHandler.hxx"
#include "OSystem.hxx"
#include "Settings.hxx"
#include "TIA.hxx"
#include "Sound.hxx"
#include "AudioSettings.hxx"
#include "MediaFactory.hxx"
#include "PNGLibrary.hxx"

#include "FBSurface.hxx"
#include "TIASurface.hxx"
#include "Bezel.hxx"
#include "FrameBuffer.hxx"
#include "StateManager.hxx"
#include "RewindManager.hxx"

#ifdef DEBUGGER_SUPPORT
  #include "Debugger.hxx"
#endif
#ifdef GUI_SUPPORT
  #include "Font.hxx"
  #include "StellaFont.hxx"
  #include "ConsoleMediumFont.hxx"
  #include "ConsoleMediumBFont.hxx"
  #include "StellaMediumFont.hxx"
  #include "StellaLargeFont.hxx"
  #include "Stella12x24tFont.hxx"
  #include "Stella14x28tFont.hxx"
  #include "Stella16x32tFont.hxx"
  #include "ConsoleFont.hxx"
  #include "Launcher.hxx"
  #include "OptionsMenu.hxx"
  #include "CommandMenu.hxx"
  #include "HighScoresMenu.hxx"
  #include "MessageMenu.hxx"
  #include "PlusRomsMenu.hxx"
  #include "TimeMachine.hxx"
#endif

static constexpr int MESSAGE_TIME = 120; // display message for 2 seconds

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FrameBuffer::FrameBuffer(OSystem& osystem)
  : myOSystem{osystem}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FrameBuffer::~FrameBuffer()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::initialize()
{
  // First create the platform-specific backend; it is needed before anything
  // else can be used
  myBackend = MediaFactory::createVideoBackend(myOSystem);

  // Get desktop resolution and supported renderers
  myBackend->queryHardware(myFullscreenDisplays, myWindowedDisplays, myRenderers);

  const size_t numDisplays = myWindowedDisplays.size();

  for(size_t display = 0; display < numDisplays; ++display)
  {
    uInt32 query_w = myWindowedDisplays[display].w, query_h = myWindowedDisplays[display].h;

    // Check the 'maxres' setting, which is an undocumented developer feature
    // that specifies the desktop size (not normally set)
    const Common::Size& s = myOSystem.settings().getSize("maxres");
    if(s.valid())
    {
      query_w = s.w;
      query_h = s.h;
    }
    // Various parts of the codebase assume a minimum screen size
    Common::Size size(std::max(query_w, FBMinimum::Width), std::max(query_h, FBMinimum::Height));
    myAbsDesktopSize.push_back(size);

    // Check for HiDPI mode (is it activated, and can we use it?)
    myHiDPIAllowed.push_back(((size.w / 2) >= FBMinimum::Width) &&
                             ((size.h / 2) >= FBMinimum::Height));
    myHiDPIEnabled.push_back(myHiDPIAllowed.back() && myOSystem.settings().getBool("hidpi"));

    // In HiDPI mode, the desktop resolution is essentially halved
    // Later, the output is scaled and rendered in 2x mode
    if(myHiDPIEnabled.back())
    {
      size.w /= hidpiScaleFactor();
      size.h /= hidpiScaleFactor();
    }
    myDesktopSize.push_back(size);
  }

#ifdef GUI_SUPPORT
  setupFonts();
#endif

  setUIPalette();

  myGrabMouse = myOSystem.settings().getBool("grabmouse");

  // Create a TIA surface; we need it for rendering TIA images
  myTIASurface = make_unique<TIASurface>(myOSystem);
  // Create a bezel surface for TIA overlays
  myBezel = make_unique<Bezel>(myOSystem);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int FrameBuffer::displayId(BufferType bufferType) const
{
  const int maxDisplay = static_cast<int>(myWindowedDisplays.size()) - 1;
  int display = 0;

  if(bufferType == myBufferType)
    display = myBackend->getCurrentDisplayIndex();
  else
    display = myOSystem.settings().getInt(getDisplayKey(bufferType != BufferType::None
                                          ? bufferType : myBufferType));

  return std::min(std::max(0, display), maxDisplay);
}

#ifdef GUI_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::setupFonts()
{
  ////////////////////////////////////////////////////////////////////
  // Create fonts to draw text
  // NOTE: the logic determining appropriate font sizes is done here,
  //       so that the UI classes can just use the font they expect,
  //       and not worry about it
  //       This logic should also take into account the size of the
  //       framebuffer, and try to be intelligent about font sizes
  //       We can probably add ifdefs to take care of corner cases,
  //       but that means we've failed to abstract it enough ...
  ////////////////////////////////////////////////////////////////////

  // This font is used in a variety of situations when a really small
  // font is needed; we let the specific widget/dialog decide when to
  // use it
  mySmallFont = make_unique<GUI::Font>(GUI::stellaDesc); // 6x10

  if(myOSystem.settings().getBool("minimal_ui"))
  {
    // The general font used in all UI elements
    myFont = make_unique<GUI::Font>(GUI::stella12x24tDesc);           // 12x24
    // The info font used in all UI elements
    myInfoFont = make_unique<GUI::Font>(GUI::stellaLargeDesc);        // 10x20
  }
  else
  {
    constexpr int NUM_FONTS = 7;
    const FontDesc FONT_DESC[NUM_FONTS] = {
      GUI::consoleDesc, GUI::consoleMediumDesc, GUI::stellaMediumDesc,
      GUI::stellaLargeDesc, GUI::stella12x24tDesc, GUI::stella14x28tDesc,
      GUI::stella16x32tDesc};
    const string_view dialogFont = myOSystem.settings().getString("dialogfont");
    const FontDesc fd = getFontDesc(dialogFont);

    // The general font used in all UI elements
    myFont = make_unique<GUI::Font>(fd);                                //  default: 9x18
    // The info font used in all UI elements,
    //  automatically determined aiming for 1 / 1.4 (~= 18 / 13) size
    int fontIdx = 0;
    for(int i = 0; i < NUM_FONTS; ++i)
    {
      if(fd.height <= FONT_DESC[i].height * 1.4)
      {
        fontIdx = i;
        break;
      }
    }
    myInfoFont = make_unique<GUI::Font>(FONT_DESC[fontIdx]);            //  default 8x13

    // Determine minimal zoom level based on the default font
    //  So what fits with default font should fit for any font.
    //  However, we have to make sure all Dialogs are sized using the fontsize.
    const int zoom_h = (fd.height * 4 * 2) / GUI::stellaMediumDesc.height;
    const int zoom_w = (fd.maxwidth * 4 * 2) / GUI::stellaMediumDesc.maxwidth;
    // round to 25% steps, >= 200%
    myTIAMinZoom = std::max(std::max(zoom_w, zoom_h) / 4., 2.);
  }

  // The font used by the ROM launcher
  const string_view lf = myOSystem.settings().getString("launcherfont");

  myLauncherFont = make_unique<GUI::Font>(getFontDesc(lf));       //  8x13
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FontDesc FrameBuffer::getFontDesc(string_view name)
{
  if(name == "small")
    return GUI::consoleDesc;        //  8x13
  else if(name == "low_medium")
    return GUI::consoleMediumBDesc; //  9x15
  else if(name == "medium")
    return GUI::stellaMediumDesc;   //  9x18
  else if(name == "large" || name == "large10")
    return GUI::stellaLargeDesc;    // 10x20
  else if(name == "large12")
    return GUI::stella12x24tDesc;   // 12x24
  else if(name == "large14")
    return GUI::stella14x28tDesc;   // 14x28
  else // "large16"
    return GUI::stella16x32tDesc;   // 16x32
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FBInitStatus FrameBuffer::createDisplay(string_view title, BufferType type,
                                        Common::Size size, bool honourHiDPI)
{
  ++myInitializedCount;
  myBackend->setTitle(title);

  // Always save, maybe only the mode of the window has changed
  saveCurrentWindowPosition();
  myBufferType = type;

  // In HiDPI mode, all created displays must be scaled appropriately
  if(honourHiDPI && hidpiEnabled())
  {
    size.w *= hidpiScaleFactor();
    size.h *= hidpiScaleFactor();
  }

  // A 'windowed' system is defined as one where the window size can be
  // larger than the screen size, as there's some sort of window manager
  // that takes care of it (all current desktop systems fall in this category)
  // However, some systems have no concept of windowing, and have hard limits
  // on how large a window can be (ie, the size of the 'desktop' is the
  // absolute upper limit on window size)
  //
  // If the WINDOWED_SUPPORT macro is defined, we treat the system as the
  // former type; if not, as the latter type

  const int display = displayId();
#ifdef WINDOWED_SUPPORT
  // We assume that a desktop of at least minimum acceptable size means that
  // we're running on a 'large' system, and the window size requirements
  // can be relaxed
  // Otherwise, we treat the system as if WINDOWED_SUPPORT is not defined
  if(myDesktopSize[display].w < FBMinimum::Width &&
     myDesktopSize[display].h < FBMinimum::Height &&
     size > myDesktopSize[display])
    return FBInitStatus::FailTooLarge;
#else
  // Make sure this mode is even possible
  // We only really need to worry about it in non-windowed environments,
  // where requesting a window that's too large will probably cause a crash
  if(size > myDesktopSize[display])
    return FBInitStatus::FailTooLarge;
#endif

  if(myBufferType == BufferType::Emulator)
  {
    myBezel->load(); // make sure we have the correct bezel size

    // Determine possible TIA windowed zoom levels
    const auto currentTIAZoom =
      static_cast<double>(myOSystem.settings().getFloat("tia.zoom"));
    myOSystem.settings().setValue("tia.zoom",
      BSPF::clamp(currentTIAZoom, supportedTIAMinZoom(), supportedTIAMaxZoom()));
  }

#ifdef GUI_SUPPORT  // TODO: put message stuff in its own class
  // Erase any messages from a previous run
  myMsg.enabled = false;

  // Create surfaces for TIA statistics and general messages
  const GUI::Font& f = hidpiEnabled() ? infoFont() : font();
  myStatsMsg.color = kColorInfo;
  myStatsMsg.w = f.getMaxCharWidth() * 40 + 3;
  myStatsMsg.h = (f.getFontHeight() + 2) * 3;

  if(!myStatsMsg.surface)
  {
    myStatsMsg.surface = allocateSurface(myStatsMsg.w, myStatsMsg.h);
    myStatsMsg.surface->attributes().blending = true;
    myStatsMsg.surface->attributes().blendalpha = 92; //aligned with TimeMachineDialog
    myStatsMsg.surface->applyAttributes();
  }

  if(!myMsg.surface)
  {
    const int fontWidth = font().getMaxCharWidth(),
              HBORDER = fontWidth * 1.25 / 2.0;
    myMsg.surface = allocateSurface(fontWidth * MESSAGE_WIDTH + HBORDER * 2,
                                    font().getFontHeight() * 1.5);
  }
#endif

  // Initialize video mode handler, so it can know what video modes are
  // appropriate for the requested image size
  myVidModeHandler.setImageSize(size);

  // Initialize video subsystem
  const string pre_about = myBackend->about();
  const FBInitStatus status = applyVideoMode();

  // Only set phosphor once when ROM is started
  if(myOSystem.eventHandler().inTIAMode())
  {
    // Phosphor mode can be enabled either globally or per-ROM
    int p_blend = 0;
    bool enable = false;
    const int phosphorMode = PhosphorHandler::toPhosphorMode(
      myOSystem.settings().getString(PhosphorHandler::SETTING_MODE));

    switch(phosphorMode)
    {
      case PhosphorHandler::Always:
        enable = true;
        p_blend = myOSystem.settings().getInt(PhosphorHandler::SETTING_BLEND);
        myOSystem.console().tia().enableAutoPhosphor(false);
        break;

      case PhosphorHandler::Auto_on:
      case PhosphorHandler::Auto:
        enable = false;
        p_blend = myOSystem.settings().getInt(PhosphorHandler::SETTING_BLEND);
        myOSystem.console().tia().enableAutoPhosphor(true, phosphorMode == PhosphorHandler::Auto_on);
        break;

      default: // PhosphorHandler::ByRom
        enable = myOSystem.console().properties().get(PropType::Display_Phosphor) == "YES";
        p_blend = BSPF::stoi(myOSystem.console().properties().get(PropType::Display_PPBlend));
        myOSystem.console().tia().enableAutoPhosphor(false);
        break;
    }
    myTIASurface->enablePhosphor(enable, p_blend);
  }

  if(status != FBInitStatus::Success)
    return status;

  // Print initial usage message, but only print it later if the status has changed
  if(myInitializedCount == 1)
  {
    Logger::info(myBackend->about());
  }
  else
  {
    const string post_about = myBackend->about();
    if(post_about != pre_about)
      Logger::info(post_about);
  }

  return status;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::update(UpdateMode mode)
{
  // Onscreen messages are a special case and require different handling than
  // other objects; they aren't UI dialogs in the normal sense nor are they
  // TIA images, and they need to be rendered on top of everything
  // The logic is split in two pieces:
  //  - at the top of ::update(), to determine whether underlying dialogs
  //    need to be force-redrawn
  //  - at the bottom of ::update(), to actually draw them (this must come
  //    last, since they are always drawn on top of everything else).

  const bool forceRedraw = mode & UpdateMode::REDRAW;
  bool redraw = forceRedraw;

  // Forced render without draw required if messages or dialogs were closed
  // Note: For dialogs only relevant when two or more dialogs were stacked
  const bool rerender = (mode & (UpdateMode::REDRAW | UpdateMode::RERENDER))
    || myPendingRender;
  myPendingRender = false;

  switch(myOSystem.eventHandler().state())
  {
    case EventHandlerState::NONE:
    case EventHandlerState::EMULATION:
      // Do nothing; emulation mode is handled separately (see below)
      return;

    case EventHandlerState::PAUSE:
    {
      // Show a pause message immediately and then every 7 seconds
      const bool shade = myOSystem.settings().getBool("pausedim");

      if(myMsg.counter < MESSAGE_TIME && myPausedCount-- <= 0)
      {
        myPausedCount = static_cast<uInt32>(7 * myOSystem.frameRate());
        showTextMessage("Paused", MessagePosition::MiddleCenter);
        renderTIA(false, shade);
      }
      if(rerender)
        renderTIA(false, shade);
      break;  // EventHandlerState::PAUSE
    }

  #ifdef GUI_SUPPORT
    case EventHandlerState::OPTIONSMENU:
    {
      myOSystem.optionsMenu().tick();
      redraw |= myOSystem.optionsMenu().needsRedraw();
      if(redraw)
      {
        renderTIA(true, true);
        myOSystem.optionsMenu().draw(forceRedraw);
      }
      else if(rerender)
      {
        renderTIA(true, true);
        myOSystem.optionsMenu().render();
      }
      break;  // EventHandlerState::OPTIONSMENU
    }

    case EventHandlerState::CMDMENU:
    {
      myOSystem.commandMenu().tick();
      redraw |= myOSystem.commandMenu().needsRedraw();
      if(redraw)
      {
        renderTIA(true, true);
        myOSystem.commandMenu().draw(forceRedraw);
      }
      else if(rerender)
      {
        renderTIA(true, true);
        myOSystem.commandMenu().render();
      }
      break;  // EventHandlerState::CMDMENU
    }

    case EventHandlerState::HIGHSCORESMENU:
    {
      myOSystem.highscoresMenu().tick();
      redraw |= myOSystem.highscoresMenu().needsRedraw();
      if(redraw)
      {
        renderTIA(true, true);
        myOSystem.highscoresMenu().draw(forceRedraw);
      }
      else if(rerender)
      {
        renderTIA(true, true);
        myOSystem.highscoresMenu().render();
      }
      break;  // EventHandlerState::HIGHSCORESMENU
    }

    case EventHandlerState::MESSAGEMENU:
    {
      myOSystem.messageMenu().tick();
      redraw |= myOSystem.messageMenu().needsRedraw();
      if(redraw)
      {
        renderTIA(true, true);
        myOSystem.messageMenu().draw(forceRedraw);
      }
      break;  // EventHandlerState::MESSAGEMENU
    }

    case EventHandlerState::PLUSROMSMENU:
    {
      myOSystem.plusRomsMenu().tick();
      redraw |= myOSystem.plusRomsMenu().needsRedraw();
      if(redraw)
      {
        renderTIA(true, true);
        myOSystem.plusRomsMenu().draw(forceRedraw);
      }
      break;  // EventHandlerState::PLUSROMSMENU
    }

    case EventHandlerState::TIMEMACHINE:
    {
      myOSystem.timeMachine().tick();
      redraw |= myOSystem.timeMachine().needsRedraw();
      if(redraw)
      {
        renderTIA();
        myOSystem.timeMachine().draw(forceRedraw);
      }
      else if(rerender)
      {
        renderTIA();
        myOSystem.timeMachine().render();
      }
      break;  // EventHandlerState::TIMEMACHINE
    }

    case EventHandlerState::PLAYBACK:
    {
      static Int32 frames = 0;
      bool success = true;

      if(--frames <= 0)
      {
        RewindManager& r = myOSystem.state().rewindManager();
        const uInt64 prevCycles = r.getCurrentCycles();

        success = r.unwindStates(1);

        // Determine playback speed, the faster the more the states are apart
        const Int64 frameCycles = static_cast<Int64>(76) * std::max<Int32>(myOSystem.console().tia().scanlinesLastFrame(), 240);
        const Int64 intervalFrames = r.getInterval() / frameCycles;
        const Int64 stateFrames = (r.getCurrentCycles() - prevCycles) / frameCycles;

        //frames = intervalFrames + std::sqrt(std::max(stateFrames - intervalFrames, 0));
        frames = std::round(std::sqrt(stateFrames));

        // Pause sound if saved states were removed or states are too far apart
        myOSystem.sound().pause(stateFrames > intervalFrames ||
            frames > static_cast<Int32>(myOSystem.audioSettings().bufferSize() / 2 + 1));
      }
      redraw |= success;
      if(redraw)
        renderTIA(false);

      // Stop playback mode at the end of the state buffer
      // and switch to Time Machine or Pause mode
      if(!success)
      {
        frames = 0;
        myOSystem.sound().pause(true);
        myOSystem.eventHandler().enterMenuMode(EventHandlerState::TIMEMACHINE);
      }
      break;  // EventHandlerState::PLAYBACK
    }

    case EventHandlerState::LAUNCHER:
    {
      myOSystem.launcher().tick();
      redraw |= myOSystem.launcher().needsRedraw();
      if(redraw)
        myOSystem.launcher().draw(forceRedraw);
      else if(rerender)
        myOSystem.launcher().render();
      break;  // EventHandlerState::LAUNCHER
    }
  #endif

  #ifdef DEBUGGER_SUPPORT
    case EventHandlerState::DEBUGGER:
    {
      myOSystem.debugger().tick();
      redraw |= myOSystem.debugger().needsRedraw();
      if(redraw)
        myOSystem.debugger().draw(forceRedraw);
      else if(rerender)
        myOSystem.debugger().render();
      break;  // EventHandlerState::DEBUGGER
    }
  #endif
    default:
      break;
  }

  // Draw any pending messages
  // The logic here determines whether to draw the message
  // If the message is to be disabled, logic inside the draw method
  // indicates that, and then the code at the top of this method sees
  // the change and redraws everything
  if(myMsg.enabled)
    redraw |= drawMessage();

  // Push buffers to screen only when necessary
  if(redraw || rerender)
    myBackend->renderToScreen();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::updateInEmulationMode(float framesPerSecond)
{
  // Update method that is specifically tailored to emulation mode
  //
  // We don't worry about selective rendering here; the rendering
  // always happens at the full framerate

  renderTIA();

  // Show frame statistics
  if(myStatsMsg.enabled)
    drawFrameStats(framesPerSecond);

  myLastScanlines = myOSystem.console().tia().frameBufferScanlinesLastFrame();
  myPausedCount = 0;

  // Draw any pending messages
  if(myMsg.enabled)
    drawMessage();

  // Push buffers to screen
  myBackend->renderToScreen();
}

#ifdef GUI_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::createMessage(string_view message, MessagePosition position,
                                bool force)
{
  // Only show messages if they've been enabled
  if(myMsg.surface == nullptr || !(force || myOSystem.settings().getBool("uimessages")))
    return;

  const int fontHeight = font().getFontHeight();
  const int VBORDER = fontHeight / 4;

  // Show message for 2 seconds
  myMsg.counter = std::min(static_cast<Int32>(myOSystem.frameRate()) * 2, MESSAGE_TIME);
  if(myMsg.counter == 0)
    myMsg.counter = MESSAGE_TIME;

  // Precompute the message coordinates
  myMsg.text      = message;
  myMsg.color     = kBtnTextColor;
  myMsg.h         = fontHeight + VBORDER * 2;
  myMsg.position  = position;
  myMsg.enabled   = true;
  myMsg.dirty     = true;

  myMsg.surface->setSrcSize(myMsg.w, myMsg.h);
  myMsg.surface->setDstSize(myMsg.w * hidpiScaleFactor(), myMsg.h * hidpiScaleFactor());
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::showTextMessage(string_view message,
                                  MessagePosition position, bool force)
{
#ifdef GUI_SUPPORT
  const int fontWidth = font().getMaxCharWidth();
  const int HBORDER = fontWidth * 1.25 / 2.0;

  myMsg.showGauge = false;
  myMsg.w         = std::min(fontWidth * (MESSAGE_WIDTH) - HBORDER * 2,
                             font().getStringWidth(message) + HBORDER * 2);

  createMessage(message, position, force);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::showGaugeMessage(string_view message, string_view valueText,
                                   float value, float minValue, float maxValue)
{
#ifdef GUI_SUPPORT
  const int fontWidth = font().getMaxCharWidth();
  const int HBORDER = fontWidth * 1.25 / 2.0;

  myMsg.showGauge  = true;
  if(maxValue - minValue != 0)
    myMsg.value = (value - minValue) / (maxValue - minValue) * 100.F;
  else
    myMsg.value = 100.F;
  myMsg.valueText  = valueText;
  myMsg.w          = std::min(fontWidth * MESSAGE_WIDTH,
                              font().getStringWidth(message)
                              + fontWidth * (GAUGEBAR_WIDTH + 2)
                              + font().getStringWidth(valueText))
                              + HBORDER * 2;

  createMessage(message, MessagePosition::BottomCenter);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FrameBuffer::messageShown() const
{
#ifdef GUI_SUPPORT
  return myMsg.enabled;
#else
  return false;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::drawFrameStats(float framesPerSecond)
{
#ifdef GUI_SUPPORT
  const ConsoleInfo& info = myOSystem.console().about();
  constexpr int xPos = 2;
  int yPos = 0;
  const GUI::Font& f = hidpiEnabled() ? infoFont() : font();
  const int dy = f.getFontHeight() + 2;

  ostringstream ss;

  myStatsMsg.surface->invalidate();

  // draw scanlines
  ColorId color = myOSystem.console().tia().frameBufferScanlinesLastFrame() !=
    myLastScanlines ? kDbgColorRed : myStatsMsg.color;

  ss
    << myOSystem.console().tia().frameBufferScanlinesLastFrame()
    << " / "
    << std::fixed << std::setprecision(1)
    << myOSystem.console().currentFrameRate()
    << "Hz => "
    << info.DisplayFormat;

  myStatsMsg.surface->drawString(f, ss.str(), xPos, yPos,
                                 myStatsMsg.w, color, TextAlign::Left, 0, true, kBGColor);

  yPos += dy;
  ss.str("");

  ss
    << std::fixed << std::setprecision(1) << framesPerSecond
    << "fps @ "
    << std::fixed << std::setprecision(0) << 100 *
      (myOSystem.settings().getBool("turbo")
        ? 50.0F
        : myOSystem.settings().getFloat("speed"))
    << "% speed";

  myStatsMsg.surface->drawString(f, ss.str(), xPos, yPos,
      myStatsMsg.w, myStatsMsg.color, TextAlign::Left, 0, true, kBGColor);

  yPos += dy;
  ss.str("");

  ss << info.BankSwitch;
  int xPosEnd =
    myStatsMsg.surface->drawString(f, ss.str(), xPos, yPos,
                                   myStatsMsg.w, myStatsMsg.color, TextAlign::Left, 0, true, kBGColor);

  if(myOSystem.settings().getBool("dev.settings"))
  {
    xPosEnd = myStatsMsg.surface->drawString(f, "| ", xPosEnd, yPos,
                                  myStatsMsg.w, color, TextAlign::Left, 0, true, kBGColor);
    ss.str("");
    color = myStatsMsg.color;
    if(myOSystem.console().vsyncCorrect())
      ss << "Developer";
    else
    {
      color = kDbgColorRed;
      ss << "VSYNC!";
    }
    myStatsMsg.surface->drawString(f, ss.str(), xPosEnd, yPos,
        myStatsMsg.w, color, TextAlign::Left, 0, true, kBGColor);
  }

  myStatsMsg.surface->setDstPos(imageRect().x() + imageRect().w() / 64,
                                imageRect().y() + imageRect().h() / 64);
  myStatsMsg.surface->setDstSize(myStatsMsg.w * hidpiScaleFactor(),
                                 myStatsMsg.h * hidpiScaleFactor());
  myStatsMsg.surface->render();
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::toggleFrameStats(bool toggle)
{
  if (toggle)
    showFrameStats(!myStatsEnabled);
  myOSystem.settings().setValue(
    myOSystem.settings().getBool("dev.settings") ? "dev.stats" : "plr.stats", myStatsEnabled);

  myOSystem.frameBuffer().showTextMessage(string("Console info ") +
                                          (myStatsEnabled ? "enabled" : "disabled"));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::showFrameStats(bool enable)
{
  myStatsEnabled = myStatsMsg.enabled = enable;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::enableMessages(bool enable)
{
  if(enable)
  {
    // Only re-enable frame stats if they were already enabled before
    myStatsMsg.enabled = myStatsEnabled;
  }
  else
  {
    // Temporarily disable frame stats
    myStatsMsg.enabled = false;

    // Erase old messages on the screen
    hideMessage();

    update();  // update immediately
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::hideMessage()
{
  myPendingRender = myMsg.enabled;
  myMsg.enabled = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline bool FrameBuffer::drawMessage()
{
#ifdef GUI_SUPPORT
  // Either erase the entire message (when time is reached),
  // or show again this frame
  if(myMsg.counter == 0)
  {
    hideMessage();
    return false;
  }

  if(myMsg.dirty)
  {
  #ifdef DEBUG_BUILD
    cerr << "m";
    //cerr << "--- draw message ---\n";
  #endif

    // Draw the bounded box and text
    const Common::Rect& dst = myMsg.surface->dstRect();
    const int fontWidth = font().getMaxCharWidth(),
              fontHeight = font().getFontHeight();
    const int VBORDER = fontHeight / 4;
    const int HBORDER = fontWidth * 1.25 / 2.0;
    constexpr int BORDER = 1;

    switch(myMsg.position)
    {
      case MessagePosition::TopLeft:
        myMsg.x = 5;
        myMsg.y = 5;
        break;

      case MessagePosition::TopCenter:
        myMsg.x = (imageRect().w() - dst.w()) >> 1;
        myMsg.y = 5;
        break;

      case MessagePosition::TopRight:
        myMsg.x = imageRect().w() - dst.w() - 5;
        myMsg.y = 5;
        break;

      case MessagePosition::MiddleLeft:
        myMsg.x = 5;
        myMsg.y = (imageRect().h() - dst.h()) >> 1;
        break;

      case MessagePosition::MiddleCenter:
        myMsg.x = (imageRect().w() - dst.w()) >> 1;
        myMsg.y = (imageRect().h() - dst.h()) >> 1;
        break;

      case MessagePosition::MiddleRight:
        myMsg.x = imageRect().w() - dst.w() - 5;
        myMsg.y = (imageRect().h() - dst.h()) >> 1;
        break;

      case MessagePosition::BottomLeft:
        myMsg.x = 5;
        myMsg.y = imageRect().h() - dst.h() - 5;
        break;

      case MessagePosition::BottomCenter:
        myMsg.x = (imageRect().w() - dst.w()) >> 1;
        myMsg.y = imageRect().h() - dst.h() - 5;
        break;

      case MessagePosition::BottomRight:
        myMsg.x = imageRect().w() - dst.w() - 5;
        myMsg.y = imageRect().h() - dst.h() - 5;
        break;
    }

    myMsg.surface->setDstPos(myMsg.x + imageRect().x(), myMsg.y + imageRect().y());
    myMsg.surface->fillRect(0, 0, myMsg.w, myMsg.h, kColor);
    myMsg.surface->fillRect(BORDER, BORDER, myMsg.w - BORDER * 2, myMsg.h - BORDER * 2, kBtnColor);
    myMsg.surface->drawString(font(), myMsg.text, HBORDER, VBORDER,
                              myMsg.w, myMsg.color);

    if(myMsg.showGauge)
    {
      constexpr int NUM_TICKMARKS = 4;
      // limit gauge bar width if texts are too long
      const int swidth = std::min(fontWidth * GAUGEBAR_WIDTH,
                                  fontWidth * (MESSAGE_WIDTH - 2)
                                  - font().getStringWidth(myMsg.text)
                                  - font().getStringWidth(myMsg.valueText));
      const int bwidth = swidth * myMsg.value / 100.F;
      const int bheight = fontHeight >> 1;
      const int x = HBORDER + font().getStringWidth(myMsg.text) + fontWidth;
      // align bar with bottom of text
      const int y = VBORDER + font().desc().ascent - bheight;

      // draw gauge bar
      myMsg.surface->fillRect(x - BORDER, y, swidth + BORDER * 2, bheight, kSliderBGColor);
      myMsg.surface->fillRect(x, y + BORDER, bwidth, bheight - BORDER * 2, kSliderColor);
      // draw tickmark in the middle of the bar
      for(int i = 1; i < NUM_TICKMARKS; ++i)
      {
        const int xt = x + swidth * i / NUM_TICKMARKS;
        const ColorId color = (bwidth < xt - x) ? kCheckColor : kSliderBGColor;
        myMsg.surface->vLine(xt, y + bheight / 2, y + bheight - 1, color);
      }
      // draw value text
      myMsg.surface->drawString(font(), myMsg.valueText,
                                x + swidth + fontWidth, VBORDER,
                                myMsg.w, myMsg.color);
    }
    myMsg.dirty = false;
    myMsg.surface->render();
    return true;
  }

  myMsg.counter--;
  myMsg.surface->render();
#endif

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::setPauseDelay()
{
  myPausedCount = static_cast<uInt32>(2 * myOSystem.frameRate());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<FBSurface> FrameBuffer::allocateSurface(
    int w, int h, ScalingInterpolation inter, const uInt32* data)
{
  mySurfaceList.push_back(myBackend->createSurface(w, h, inter, data));
  return mySurfaceList.back();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::deallocateSurface(const shared_ptr<FBSurface>& surface)
{
  if(surface)
    mySurfaceList.remove(surface);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::resetSurfaces()
{
  for(auto& surface: mySurfaceList)
    surface->reload();

  update(UpdateMode::REDRAW); // force full update
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::renderTIA(bool doClear, bool shade)
{
  if(doClear)
    clear();  // TODO - test this: it may cause slowdowns on older systems

  myTIASurface->render(shade);
  if(myBezel)
    myBezel->render();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::setTIAPalette(const PaletteArray& rgb_palette)
{
  // Create a TIA palette from the raw RGB data
  PaletteArray tia_palette = {0};
  for(int i = 0; i < 256; ++i)
  {
    const uInt8 r = (rgb_palette[i] >> 16) & 0xff;
    const uInt8 g = (rgb_palette[i] >> 8) & 0xff;
    const uInt8 b =  rgb_palette[i] & 0xff;

    tia_palette[i] = mapRGB(r, g, b);
  }

  // Remember the TIA palette; place it at the beginning of the full palette
  std::copy_n(tia_palette.begin(), tia_palette.size(), myFullPalette.begin());

  // Let the TIA surface know about the new palette
  myTIASurface->setPalette(tia_palette, rgb_palette);

  // Since the UI palette shares the TIA palette, we need to update it too
  setUIPalette();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::setUIPalette()
{
  const Settings& settings = myOSystem.settings();
  const string& key = settings.getBool("altuipalette") ? "uipalette2" : "uipalette";
  // Set palette for UI (upper area of full palette)
  const UIPaletteArray& ui_palette =
     (settings.getString(key) == "classic") ? ourClassicUIPalette :
     (settings.getString(key) == "light")   ? ourLightUIPalette :
     (settings.getString(key) == "dark")    ? ourDarkUIPalette :
      ourStandardUIPalette;

  for(size_t i = 0, j = myFullPalette.size() - ui_palette.size();
      i < ui_palette.size(); ++i, ++j)
  {
    const uInt8 r = (ui_palette[i] >> 16) & 0xff,
                g = (ui_palette[i] >> 8) & 0xff,
                b =  ui_palette[i] & 0xff;

    myFullPalette[j] = mapRGB(r, g, b);
  }
  FBSurface::setPalette(myFullPalette);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::stateChanged(EventHandlerState state)
{
  // Prevent removing state change messages
  if(myMsg.counter < MESSAGE_TIME - 1)
  {
    // Make sure any onscreen messages are removed
    hideMessage();
  }
  update(); // update immediately
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string FrameBuffer::getDisplayKey(BufferType bufferType) const
{
  if(bufferType == BufferType::None)
    bufferType = myBufferType;

  // save current window's display and position
  switch(bufferType)
  {
    case BufferType::Launcher:
      return "launcherdisplay";

    case BufferType::Emulator:
      return "display";

    #ifdef DEBUGGER_SUPPORT
    case BufferType::Debugger:
      return "dbg.display";
    #endif

    default:
      return "";
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string FrameBuffer::getPositionKey() const
{
  // save current window's display and position
  switch(myBufferType)
  {
    case BufferType::Launcher:
      return "launcherpos";

    case BufferType::Emulator:
      return  "windowedpos";

    #ifdef DEBUGGER_SUPPORT
    case BufferType::Debugger:
      return "dbg.pos";
    #endif

    default:
      return "";
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::saveCurrentWindowPosition() const
{
  if(myBackend)
  {
    myOSystem.settings().setValue(
      getDisplayKey(), myBackend->getCurrentDisplayIndex());
    if(myBackend->isCurrentWindowPositioned())
      myOSystem.settings().setValue(
        getPositionKey(), myBackend->getCurrentWindowPos());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::saveConfig(Settings& settings) const
{
  // Save the last windowed position and display on system shutdown
  saveCurrentWindowPosition();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::setFullscreen(bool enable)
{
#ifdef WINDOWED_SUPPORT
  // Switching between fullscreen and windowed modes will invariably mean
  // that the 'window' resolution changes.  Currently, dialogs are not
  // able to resize themselves when they are actively being shown
  // (they would have to be closed and then re-opened, etc).
  // For now, we simply disallow screen switches in such modes
  switch(myOSystem.eventHandler().state())
  {
    case EventHandlerState::EMULATION:
    case EventHandlerState::PAUSE:
      break; // continue with processing (aka, allow a mode switch)
    case EventHandlerState::DEBUGGER:
    case EventHandlerState::LAUNCHER:
      if(myOSystem.eventHandler().overlay().baseDialogIsActive())
        break; // allow a mode switch when there is only one dialog
      [[fallthrough]];
    default:
      return;
  }

  myOSystem.settings().setValue("fullscreen", enable);
  saveCurrentWindowPosition();
  applyVideoMode();
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::toggleFullscreen(bool toggle)
{
  const EventHandlerState state = myOSystem.eventHandler().state();

  switch(state)
  {
    case EventHandlerState::LAUNCHER:
    case EventHandlerState::EMULATION:
    case EventHandlerState::PAUSE:
    case EventHandlerState::DEBUGGER:
    {
      const bool isFullscreen = toggle ? !fullScreen() : fullScreen();
      setFullscreen(isFullscreen);

      if(state != EventHandlerState::LAUNCHER)
      {
        ostringstream msg;
        msg << "Fullscreen ";

        if(state != EventHandlerState::DEBUGGER)
        {
          if(isFullscreen)
            msg << "enabled (" << myBackend->refreshRate() << " Hz, ";
          else
            msg << "disabled (";
          msg << "Zoom " << round(myActiveVidMode.zoom * 100) << "%)";
        }
        else
        {
          if(isFullscreen)
            msg << "enabled";
          else
            msg << "disabled";
        }
        showTextMessage(msg.str());
      }
      break;
    }
    default:
      break;
  }
}

#ifdef ADAPTABLE_REFRESH_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::toggleAdaptRefresh(bool toggle)
{
  bool isAdaptRefresh = myOSystem.settings().getInt("tia.fs_refresh");

  if(toggle)
    isAdaptRefresh = !isAdaptRefresh;

  if(myBufferType == BufferType::Emulator)
  {
    if(toggle)
    {
      myOSystem.settings().setValue("tia.fs_refresh", isAdaptRefresh);
      // issue a complete framebuffer re-initialization
      myOSystem.createFrameBuffer();
    }

    ostringstream msg;

    msg << "Adapt refresh rate ";
    msg << (isAdaptRefresh ? "enabled" : "disabled");
    msg << " (" << myBackend->refreshRate() << " Hz)";

    showTextMessage(msg.str());
  }
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::changeOverscan(int direction)
{
  if (fullScreen())
  {
    const int oldOverscan = myOSystem.settings().getInt("tia.fs_overscan");
    const int overscan = BSPF::clamp(oldOverscan + direction, 0, 10);

    if (overscan != oldOverscan)
    {
      myOSystem.settings().setValue("tia.fs_overscan", overscan);

      // issue a complete framebuffer re-initialization
      myOSystem.createFrameBuffer();
    }

    ostringstream val;
    if(overscan)
      val << (overscan > 0 ? "+" : "" ) << overscan << "%";
    else
      val << "Off";
    myOSystem.frameBuffer().showGaugeMessage("Overscan", val.str(), overscan, 0, 10);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::switchVideoMode(int direction)
{
  // Only applicable when in TIA/emulation mode
  if(!myOSystem.eventHandler().inTIAMode())
    return;

  if(!fullScreen())
  {
    // Windowed TIA modes support variable zoom levels
    auto zoom = static_cast<double>(myOSystem.settings().getFloat("tia.zoom"));
    if(direction == +1)       zoom += ZOOM_STEPS;
    else if(direction == -1)  zoom -= ZOOM_STEPS;

    // Make sure the level is within the allowable desktop size
    zoom = BSPF::clampw(zoom, supportedTIAMinZoom(), supportedTIAMaxZoom());
    myOSystem.settings().setValue("tia.zoom", zoom);
  }
  else
  {
    // In fullscreen mode, there are only two modes, so direction
    // is irrelevant
    if(direction == +1 || direction == -1)
    {
      const bool stretch = myOSystem.settings().getBool("tia.fs_stretch");
      myOSystem.settings().setValue("tia.fs_stretch", !stretch);
    }
  }

  saveCurrentWindowPosition();
  if(!direction || applyVideoMode() == FBInitStatus::Success)
  {
    if(fullScreen())
      showTextMessage(myActiveVidMode.description);
    else
      showGaugeMessage("Zoom", myActiveVidMode.description, myActiveVidMode.zoom,
                  supportedTIAMinZoom(), supportedTIAMaxZoom());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::toggleBezel(bool toggle)
{
  bool enabled = myOSystem.settings().getBool("bezel.show");

  if(toggle && myBufferType == BufferType::Emulator)
  {
    if(!fullScreen() && !myOSystem.settings().getBool("bezel.windowed"))
    {
      myOSystem.frameBuffer().showTextMessage("Bezels in windowed mode are not enabled");
      return;
    }
    else
    {
      enabled = !enabled;
      myOSystem.settings().setValue("bezel.show", enabled);
      if(!myBezel->load() && enabled)
      {
        myOSystem.settings().setValue("bezel.show", !enabled);
        return;
      }
      else
      {
        // Determine possible TIA windowed zoom levels
        const auto currentTIAZoom =
          static_cast<double>(myOSystem.settings().getFloat("tia.zoom"));
        myOSystem.settings().setValue("tia.zoom",
          BSPF::clamp(currentTIAZoom, supportedTIAMinZoom(), supportedTIAMaxZoom()));

        saveCurrentWindowPosition();
        applyVideoMode();
      }
    }
  }
  myOSystem.frameBuffer().showTextMessage(enabled ? "Bezel enabled" : "Bezel disabled");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FBInitStatus FrameBuffer::applyVideoMode()
{
  // Update display size, in case windowed/fullscreen mode has changed
  const Settings& s = myOSystem.settings();
  const int display = displayId();

  if(s.getBool("fullscreen"))
    myVidModeHandler.setDisplaySize(myFullscreenDisplays[display], display);
  else
    myVidModeHandler.setDisplaySize(myAbsDesktopSize[display]);

  const bool inTIAMode = myOSystem.eventHandler().inTIAMode();

#ifdef IMAGE_SUPPORT
  if(inTIAMode)
    myBezel->load();
#endif

  // Build the new mode based on current settings
  const VideoModeHandler::Mode& mode
    = myVidModeHandler.buildMode(s, inTIAMode, myBezel->info());
  if(mode.imageR.size() > mode.screenS)
    return FBInitStatus::FailTooLarge;

  // Changing the video mode can take some time, during which the last
  // sound played may get 'stuck'
  // So we pause the sound until the operation completes
  const bool oldPauseState = myOSystem.sound().pause(true);
  FBInitStatus status = FBInitStatus::FailNotSupported;

  if(myBackend->setVideoMode(mode,
      myOSystem.settings().getInt(getDisplayKey()),
      myOSystem.settings().getPoint(getPositionKey()))
    )
  {
    myActiveVidMode = mode;
    status = FBInitStatus::Success;

    // Did we get the requested fullscreen state?
    myOSystem.settings().setValue("fullscreen", fullScreen());

    // Inform TIA surface about new mode, and update TIA settings
    if(inTIAMode)
    {
      myTIASurface->initialize(myOSystem.console(), myActiveVidMode);
      if(fullScreen())
        myOSystem.settings().setValue("tia.fs_stretch",
          myActiveVidMode.stretch == VideoModeHandler::Mode::Stretch::Fill);
      else
        myOSystem.settings().setValue("tia.zoom", myActiveVidMode.zoom);

      myBezel->apply();
    }

    resetSurfaces();
    setCursorState();
    myPendingRender = true;
  }
  else
    Logger::error("ERROR: Couldn't initialize video subsystem");

  // Restore sound settings
  myOSystem.sound().pause(oldPauseState);

  return status;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
double FrameBuffer::maxWindowZoom() const
{
  const int display = displayId(BufferType::Emulator);
  double multiplier = 1;

  for(;;)
  {
    // Figure out the zoomed size of the window (incl. the bezel)
    const uInt32 width  = static_cast<double>(TIAConstants::viewableWidth)  * myBezel->ratioW() * multiplier;
    const uInt32 height = static_cast<double>(TIAConstants::viewableHeight) * myBezel->ratioH() * multiplier;

    if((width > myAbsDesktopSize[display].w) ||
       (height > myAbsDesktopSize[display].h))
      break;

    multiplier += ZOOM_STEPS;
  }
  return multiplier > 1 ? multiplier - ZOOM_STEPS : 1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::setCursorState()
{
  myGrabMouse = myOSystem.settings().getBool("grabmouse");
  // Always grab mouse in emulation (if enabled) and emulating a controller
  // that always uses the mouse
  const bool emulation =
      myOSystem.eventHandler().state() == EventHandlerState::EMULATION;
  const bool usesLightgun = emulation && myOSystem.hasConsole() ?
    myOSystem.console().leftController().type() == Controller::Type::Lightgun ||
    myOSystem.console().rightController().type() == Controller::Type::Lightgun : false;
  // Show/hide cursor in UI/emulation mode based on 'cursor' setting
  int cursor = myOSystem.settings().getInt("cursor");

  // Always enable cursor in lightgun games
  if (usesLightgun && !myGrabMouse)
    cursor |= 1;  // +Emulation

  switch(cursor)
  {
    case 0:                   // -UI, -Emulation
      showCursor(false);
      break;
    case 1:
      showCursor(emulation);  // -UI, +Emulation
      break;
    case 2:                   // +UI, -Emulation
      showCursor(!emulation);
      break;
    case 3:
      showCursor(true);       // +UI, +Emulation
      break;
    default:
      break;
  }

  myGrabMouse &= grabMouseAllowed();
  myBackend->grabMouse(myGrabMouse);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FrameBuffer::grabMouseAllowed()
{
  // Allow grabbing mouse in emulation (if enabled) and emulating a controller
  // that always uses the mouse
  const bool emulation =
    myOSystem.eventHandler().state() == EventHandlerState::EMULATION;
  const bool analog = myOSystem.hasConsole() ?
    (myOSystem.console().leftController().isAnalog() ||
     myOSystem.console().rightController().isAnalog()) : false;
  const bool usesLightgun = emulation && myOSystem.hasConsole() ?
    myOSystem.console().leftController().type() == Controller::Type::Lightgun ||
    myOSystem.console().rightController().type() == Controller::Type::Lightgun : false;
  const bool alwaysUseMouse = BSPF::equalsIgnoreCase("always", myOSystem.settings().getString("usemouse"));

  // Disable grab while cursor is shown in emulation
  const bool cursorHidden = !(myOSystem.settings().getInt("cursor") & 1);

  return emulation && (analog || usesLightgun || alwaysUseMouse) && cursorHidden;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::enableGrabMouse(bool enable)
{
  myGrabMouse = enable;
  setCursorState();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameBuffer::toggleGrabMouse(bool toggle)
{
  bool oldState = myGrabMouse = myOSystem.settings().getBool("grabmouse");

  if(toggle)
  {
    if(grabMouseAllowed())
    {
      myGrabMouse = !myGrabMouse;
      myOSystem.settings().setValue("grabmouse", myGrabMouse);
      setCursorState();
    }
  }
  else
    oldState = !myGrabMouse; // display current state

  myOSystem.frameBuffer().showTextMessage(oldState != myGrabMouse ? myGrabMouse
                                          ? "Grab mouse enabled" : "Grab mouse disabled"
                                          : "Grab mouse not allowed");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
/*
  Palette is defined as follows:
    *** Base colors ***
    kColor            Normal foreground color (non-text)
    kBGColor          Normal background color (non-text)
    kBGColorLo        Disabled background color dark (non-text)
    kBGColorHi        Disabled background color light (non-text)
    kShadowColor      Item is disabled (unused)
    *** Text colors ***
    kTextColor        Normal text color
    kTextColorHi      Highlighted text color
    kTextColorEm      Emphasized text color
    kTextColorInv     Color for selected text
    kTextColorLink    Color for links
    *** UI elements (dialog and widgets) ***
    kDlgColor         Dialog background
    kWidColor         Widget background
    kWidColorHi       Widget highlight color
    kWidFrameColor    Border for currently selected widget
    *** Button colors ***
    kBtnColor         Normal button background
    kBtnColorHi       Highlighted button background
    kBtnBorderColor,
    kBtnBorderColorHi,
    kBtnTextColor     Normal button font color
    kBtnTextColorHi   Highlighted button font color
    *** Checkbox colors ***
    kCheckColor       Color of 'X' in checkbox
    *** Scrollbar colors ***
    kScrollColor      Normal scrollbar color
    kScrollColorHi    Highlighted scrollbar color
    *** Debugger colors ***
    kDbgChangedColor      Background color for changed cells
    kDbgChangedTextColor  Text color for changed cells
    kDbgColorHi           Highlighted color in debugger data cells
    kDbgColorRed          Red color in debugger
    *** Slider colors ***
    kSliderColor          Enabled slider
    kSliderColorHi        Focussed slider
    kSliderBGColor        Enabled slider background
    kSliderBGColorHi      Focussed slider background
    kSliderBGColorLo      Disabled slider background
    *** Other colors ***
    kColorInfo            TIA output position color
    kColorTitleBar        Title bar color
    kColorTitleText       Title text color
*/
UIPaletteArray FrameBuffer::ourStandardUIPalette = {
  { 0x686868, 0x000000, 0xa38c61, 0xdccfa5, 0x404040,           // base
    0x000000, 0xac3410, 0x9f0000, 0xf0f0cf, 0xac3410,           // text
    0xc9af7c, 0xf0f0cf, 0xd55941, 0xc80000,                     // UI elements
    0xac3410, 0xd55941, 0x686868, 0xdccfa5, 0xf0f0cf, 0xf0f0cf, // buttons
    0xac3410,                                                   // checkbox
    0xac3410, 0xd55941,                                         // scrollbar
    0xc80000, 0xffff80, 0xc8c8ff, 0xc80000,                     // debugger
    0xac3410, 0xd55941, 0xdccfa5, 0xf0f0cf, 0xa38c61,           // slider
    0xffffff, 0xac3410, 0xf0f0cf                                // other
  }
};

UIPaletteArray FrameBuffer::ourClassicUIPalette = {
  { 0x686868, 0x000000, 0x404040, 0x404040, 0x404040,           // base
    0x20a020, 0x00ff00, 0xc80000, 0x000000, 0x00ff00,           // text
    0x000000, 0x000000, 0x00ff00, 0xc80000,                     // UI elements
    0x000000, 0x000000, 0x686868, 0x00ff00, 0x20a020, 0x00ff00, // buttons
    0x20a020,                                                   // checkbox
    0x20a020, 0x00ff00,                                         // scrollbar
    0xc80000, 0x00ff00, 0xc8c8ff, 0xc80000,                     // debugger
    0x20a020, 0x00ff00, 0x404040, 0x686868, 0x404040,           // slider
    0x00ff00, 0x20a020, 0x000000                                // other
  }
};

UIPaletteArray FrameBuffer::ourLightUIPalette = {
  { 0x808080, 0x000000, 0xc0c0c0, 0xe1e1e1, 0x333333,           // base
    0x000000, 0xBDDEF9, 0x0078d7, 0x000000, 0x005aa1,           // text
    0xf0f0f0, 0xffffff, 0x0078d7, 0x0f0f0f,                     // UI elements
    0xe1e1e1, 0xe5f1fb, 0x808080, 0x0078d7, 0x000000, 0x000000, // buttons
    0x333333,                                                   // checkbox
    0xc0c0c0, 0x808080,                                         // scrollbar
    0xffc0c0, 0x000000, 0xe00000, 0xc00000,                     // debugger
    0x333333, 0x0078d7, 0xc0c0c0, 0xffffff, 0xc0c0c0,           // slider 0xBDDEF9| 0xe1e1e1 | 0xffffff
    0xffffff, 0x333333, 0xf0f0f0                                // other
  }
};

UIPaletteArray FrameBuffer::ourDarkUIPalette = {
  { 0x646464, 0xc0c0c0, 0x3c3c3c, 0x282828, 0x989898,           // base
    0xc0c0c0, 0x1567a5, 0x0064b7, 0xc0c0c0, 0x1d92e0,           // text
    0x202020, 0x000000, 0x0059a3, 0xb0b0b0,                     // UI elements
    0x282828, 0x00467f, 0x646464, 0x0059a3, 0xc0c0c0, 0xc0c0c0, // buttons
    0x989898,                                                   // checkbox
    0x3c3c3c, 0x646464,                                         // scrollbar
    0x7f2020, 0xc0c0c0, 0xe00000, 0xc00000,                     // debugger
    0x989898, 0x0059a3, 0x3c3c3c, 0x000000, 0x3c3c3c,           // slider
    0x000000, 0x404040, 0xc0c0c0                                // other
  }
};
