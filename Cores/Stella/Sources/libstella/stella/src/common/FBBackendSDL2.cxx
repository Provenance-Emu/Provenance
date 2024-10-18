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

#include <cmath>

#include "bspf.hxx"
#include "Logger.hxx"

#include "Console.hxx"
#include "OSystem.hxx"
#include "Settings.hxx"

#include "ThreadDebugging.hxx"
#include "FBSurfaceSDL2.hxx"
#include "FBBackendSDL2.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FBBackendSDL2::FBBackendSDL2(OSystem& osystem)
  : myOSystem{osystem}
{
  ASSERT_MAIN_THREAD;

  // Initialize SDL2 context
  if(SDL_InitSubSystem(SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0)
  {
    ostringstream buf;
    buf << "ERROR: Couldn't initialize SDL: " << SDL_GetError();
    throw runtime_error(buf.str());
  }
  Logger::debug("FBBackendSDL2::FBBackendSDL2 SDL_Init()");

  // We need a pixel format for palette value calculations
  // It's done this way (vs directly accessing a FBSurfaceSDL2 object)
  // since the structure may be needed before any FBSurface's have
  // been created
  myPixelFormat = SDL_AllocFormat(SDL_PIXELFORMAT_ARGB8888);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FBBackendSDL2::~FBBackendSDL2()
{
  ASSERT_MAIN_THREAD;

  SDL_FreeFormat(myPixelFormat);

  if(myRenderer)
  {
    SDL_DestroyRenderer(myRenderer);
    myRenderer = nullptr;
  }
  if(myWindow)
  {
    SDL_SetWindowFullscreen(myWindow, 0); // on some systems, a crash occurs
                                          // when destroying fullscreen window
    SDL_DestroyWindow(myWindow);
    myWindow = nullptr;
  }
  SDL_QuitSubSystem(SDL_INIT_VIDEO | SDL_INIT_TIMER);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::queryHardware(vector<Common::Size>& fullscreenRes,
                                  vector<Common::Size>& windowedRes,
                                  VariantList& renderers)
{
  ASSERT_MAIN_THREAD;

  // Get number of displays (for most systems, this will be '1')
  myNumDisplays = SDL_GetNumVideoDisplays();

  // First get the maximum fullscreen desktop resolution
  SDL_DisplayMode display;
  for(int i = 0; i < myNumDisplays; ++i)
  {
    SDL_GetDesktopDisplayMode(i, &display);
    fullscreenRes.emplace_back(display.w, display.h);

    // evaluate fullscreen display modes (debug only for now)
    const int numModes = SDL_GetNumDisplayModes(i);
    ostringstream s;

    s << "Supported video modes (" << numModes << ") for display " << i
      << " (" << SDL_GetDisplayName(i) << "):";

    string lastRes;
    for(int m = 0; m < numModes; ++m)
    {
      SDL_DisplayMode mode;
      ostringstream res;

      SDL_GetDisplayMode(i, m, &mode);
      res << std::setw(4) << mode.w << "x" << std::setw(4) << mode.h;

      if(lastRes != res.str())
      {
        Logger::debug(s.str());
        s.str("");
        lastRes = res.str();
        s << "  " << lastRes << ": ";
      }
      s << mode.refresh_rate << "Hz";
      if(mode.w == display.w && mode.h == display.h && mode.refresh_rate == display.refresh_rate)
        s << "* ";
      else
        s << "  ";
    }
    Logger::debug(s.str());
  }

  // Now get the maximum windowed desktop resolution
  // Try to take into account taskbars, etc, if available
#if SDL_VERSION_ATLEAST(2,0,5)
  // Take window title-bar into account; SDL_GetDisplayUsableBounds doesn't do that
  int wTop = 0, wLeft = 0, wBottom = 0, wRight = 0;
  SDL_Window* tmpWindow = SDL_CreateWindow("", 0, 0, 0, 0, SDL_WINDOW_HIDDEN);
  if(tmpWindow != nullptr)
  {
    SDL_GetWindowBordersSize(tmpWindow, &wTop, &wLeft, &wBottom, &wRight);
    SDL_DestroyWindow(tmpWindow);
  }

  SDL_Rect r;
  for(int i = 0; i < myNumDisplays; ++i)
  {
    // Display bounds minus dock
    SDL_GetDisplayUsableBounds(i, &r);  // Requires SDL-2.0.5 or higher
    r.h -= (wTop + wBottom);
    windowedRes.emplace_back(r.w, r.h);
  }
#else
  for(int i = 0; i < myNumDisplays; ++i)
  {
    SDL_GetDesktopDisplayMode(i, &display);
    windowedRes.emplace_back(display.w, display.h);
  }
#endif

  struct RenderName
  {
    string sdlName;
    string stellaName;
  };
  // Create name map for all currently known SDL renderers
  static const std::array<RenderName, 8> RENDERER_NAMES = {{
    { "direct3d",   "Direct3D"    },
    { "direct3d11", "Direct3D 11" },
    { "direct3d12", "Direct3D 12" },
    { "metal",      "Metal"       },
    { "opengl",     "OpenGL"      },
    { "opengles",   "OpenGL ES"   },
    { "opengles2",  "OpenGL ES 2" },
    { "software",   "Software"    }
  }};

  const int numDrivers = SDL_GetNumRenderDrivers();
  for(int i = 0; i < numDrivers; ++i)
  {
    SDL_RendererInfo info;
    if(SDL_GetRenderDriverInfo(i, &info) == 0)
    {
      // Map SDL names into nicer Stella names (if available)
      bool found = false;
      for(const auto& render: RENDERER_NAMES)
      {
        if(render.sdlName == info.name)
        {
          VarList::push_back(renderers, render.stellaName, info.name);
          found = true;
          break;
        }
      }
      if(!found)
        VarList::push_back(renderers, info.name, info.name);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FBBackendSDL2::isCurrentWindowPositioned() const
{
  ASSERT_MAIN_THREAD;

  return !myCenter
    && myWindow && !(SDL_GetWindowFlags(myWindow) & SDL_WINDOW_FULLSCREEN_DESKTOP);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Point FBBackendSDL2::getCurrentWindowPos() const
{
  ASSERT_MAIN_THREAD;

  Common::Point pos;

  SDL_GetWindowPosition(myWindow, &pos.x, &pos.y);

  return pos;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Int32 FBBackendSDL2::getCurrentDisplayIndex() const
{
  ASSERT_MAIN_THREAD;

  return SDL_GetWindowDisplayIndex(myWindow);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FBBackendSDL2::setVideoMode(const VideoModeHandler::Mode& mode,
                                 int winIdx, const Common::Point& winPos)
{
  ASSERT_MAIN_THREAD;

  // If not initialized by this point, then immediately fail
  if(SDL_WasInit(SDL_INIT_VIDEO) == 0)
    return false;

  const bool fullScreen = mode.fsIndex != -1;
  const Int32 displayIndex = std::min(myNumDisplays - 1, winIdx);

  int posX = 0, posY = 0;

  myCenter = myOSystem.settings().getBool("center");
  if(myCenter)
    posX = posY = SDL_WINDOWPOS_CENTERED_DISPLAY(displayIndex);
  else
  {
    posX = winPos.x;
    posY = winPos.y;

    // Make sure the window is at least partially visibile
    int x0 = INT_MAX, y0 = INT_MAX, x1 = 0, y1 = 0;

    for(int display = myNumDisplays - 1; display >= 0; --display)
    {
      SDL_Rect rect;

      if (!SDL_GetDisplayUsableBounds(display, &rect))
      {
        x0 = std::min(x0, rect.x);
        y0 = std::min(y0, rect.y);
        x1 = std::max(x1, rect.x + rect.w);
        y1 = std::max(y1, rect.y + rect.h);
      }
    }
    posX = BSPF::clamp(posX, x0 - static_cast<Int32>(mode.screenS.w) + 50, x1 - 50);
    posY = BSPF::clamp(posY, y0 + 50, y1 - 50);
  }

#ifdef ADAPTABLE_REFRESH_SUPPORT
  SDL_DisplayMode adaptedSdlMode;
  const int gameRefreshRate =
      myOSystem.hasConsole() ? myOSystem.console().gameRefreshRate() : 0;
  const bool shouldAdapt = fullScreen
    && myOSystem.settings().getBool("tia.fs_refresh")
    && gameRefreshRate
    // take care of 59.94 Hz
    && refreshRate() % gameRefreshRate != 0
    && refreshRate() % (gameRefreshRate - 1) != 0;
  const bool adaptRefresh = shouldAdapt &&
      adaptRefreshRate(displayIndex, adaptedSdlMode);
#else
  const bool adaptRefresh = false;
#endif
  const uInt32 flags = SDL_WINDOW_ALLOW_HIGHDPI
    | (fullScreen ? adaptRefresh ? SDL_WINDOW_FULLSCREEN :
    SDL_WINDOW_FULLSCREEN_DESKTOP : 0);

  // Don't re-create the window if its display and size hasn't changed,
  // as it's not necessary, and causes flashing in fullscreen mode
  if(myWindow)
  {
    const int d = SDL_GetWindowDisplayIndex(myWindow);
    int w{0}, h{0};

    SDL_GetWindowSize(myWindow, &w, &h);
    if(d != displayIndex || static_cast<uInt32>(w) != mode.screenS.w ||
      static_cast<uInt32>(h) != mode.screenS.h || adaptRefresh)
    {
      // Renderer has to be destroyed *before* the window gets destroyed to avoid memory leaks
      SDL_DestroyRenderer(myRenderer);
      myRenderer = nullptr;
      SDL_DestroyWindow(myWindow);
      myWindow = nullptr;
    }
  }

  if(myWindow)
  {
    // Even though window size stayed the same, the title may have changed
    SDL_SetWindowTitle(myWindow, myScreenTitle.c_str());
    SDL_SetWindowPosition(myWindow, posX, posY);
  }
  else
  {
    myWindow = SDL_CreateWindow(myScreenTitle.c_str(), posX, posY,
                                mode.screenS.w, mode.screenS.h, flags);
    if(myWindow == nullptr)
    {
      const string msg = "ERROR: Unable to open SDL window: " + string(SDL_GetError());
      Logger::error(msg);
      return false;
    }

    setWindowIcon();
  }

#ifdef ADAPTABLE_REFRESH_SUPPORT
  if(adaptRefresh)
  {
    // Switch to mode for adapted refresh rate
    if(SDL_SetWindowDisplayMode(myWindow, &adaptedSdlMode) != 0)
    {
      Logger::error("ERROR: Display refresh rate change failed");
    }
    else
    {
      ostringstream msg;

      msg << "Display refresh rate changed to "
          << adaptedSdlMode.refresh_rate << " Hz " << "(" << adaptedSdlMode.w << "x" << adaptedSdlMode.h << ")";
      Logger::info(msg.str());

      SDL_DisplayMode setSdlMode;
      SDL_GetWindowDisplayMode(myWindow, &setSdlMode);
      cerr << setSdlMode.refresh_rate << "Hz\n";
    }
  }
#endif

  return createRenderer();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FBBackendSDL2::adaptRefreshRate(Int32 displayIndex,
                                     SDL_DisplayMode& adaptedSdlMode)
{
  ASSERT_MAIN_THREAD;

  SDL_DisplayMode sdlMode;

  if(SDL_GetCurrentDisplayMode(displayIndex, &sdlMode) != 0)
  {
    Logger::error("ERROR: Display mode could not be retrieved");
    return false;
  }

  const int currentRefreshRate = sdlMode.refresh_rate;
  const int wantedRefreshRate =
      myOSystem.hasConsole() ? myOSystem.console().gameRefreshRate() : 0;
  // Take care of rounded refresh rates (e.g. 59.94 Hz)
  float factor = std::min(
      static_cast<float>(currentRefreshRate) / wantedRefreshRate, static_cast<float>(currentRefreshRate) / (wantedRefreshRate - 1));
  // Calculate difference taking care of integer factors (e.g. 100/120)
  float bestDiff = std::abs(factor - std::round(factor)) / factor;
  bool adapt = false;

  // Display refresh rate should be an integer factor of the game's refresh rate
  // Note: Modes are scanned with size being first priority,
  //       therefore the size will never change.
  // Check for integer factors 1 (60/50 Hz) and 2 (120/100 Hz)
  for(int m = 1; m <= 2; ++m)
  {
    SDL_DisplayMode closestSdlMode;

    sdlMode.refresh_rate = wantedRefreshRate * m;
    if(SDL_GetClosestDisplayMode(displayIndex, &sdlMode, &closestSdlMode) == nullptr)
    {
      Logger::error("ERROR: Closest display mode could not be retrieved");
      return adapt;
    }
    factor = std::min(
        static_cast<float>(sdlMode.refresh_rate) / sdlMode.refresh_rate,
        static_cast<float>(sdlMode.refresh_rate) / (sdlMode.refresh_rate - 1));
    const float diff = std::abs(factor - std::round(factor)) / factor;
    if(diff < bestDiff)
    {
      bestDiff = diff;
      adaptedSdlMode = closestSdlMode;
      adapt = true;
    }
  }
  //cerr << "refresh rate adapt ";
  //if(adapt)
  //  cerr << "required (" << currentRefreshRate << " Hz -> " << adaptedSdlMode.refresh_rate << " Hz)";
  //else
  //  cerr << "not required/possible";
  //cerr << '\n';

  // Only change if the display supports a better refresh rate
  return adapt;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FBBackendSDL2::createRenderer()
{
  ASSERT_MAIN_THREAD;

  // A new renderer is only created when necessary:
  // - no renderer existing
  // - different renderer flags
  // - different renderer name
  bool recreate = myRenderer == nullptr;
  uInt32 renderFlags = SDL_RENDERER_ACCELERATED;
  const string& video = myOSystem.settings().getString("video");  // Render hint
  SDL_RendererInfo renderInfo;

  if(myOSystem.settings().getBool("vsync")
     && !myOSystem.settings().getBool("turbo"))  // V'synced blits option
    renderFlags |= SDL_RENDERER_PRESENTVSYNC;

  // check renderer flags and name
  recreate |= (SDL_GetRendererInfo(myRenderer, &renderInfo) != 0)
    || ((renderInfo.flags & (SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)) != renderFlags
    || (video != renderInfo.name));

  if(recreate)
  {
    //cerr << "Create new renderer for buffer type #" << int(myBufferType) << '\n';
    if(myRenderer)
      SDL_DestroyRenderer(myRenderer);

    if(!video.empty())
      SDL_SetHint(SDL_HINT_RENDER_DRIVER, video.c_str());

    myRenderer = SDL_CreateRenderer(myWindow, -1, renderFlags);

    detectFeatures();
    determineDimensions();

    if(myRenderer == nullptr)
    {
      Logger::error("ERROR: Unable to create SDL renderer: " +
                    string{SDL_GetError()});
      return false;
    }
  }
  clear();

  SDL_RendererInfo renderinfo;

  if(SDL_GetRendererInfo(myRenderer, &renderinfo) >= 0)
    myOSystem.settings().setValue("video", renderinfo.name);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::setTitle(string_view title)
{
  ASSERT_MAIN_THREAD;

  myScreenTitle = title;

  if(myWindow)
    SDL_SetWindowTitle(myWindow, string{title}.c_str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string FBBackendSDL2::about() const
{
  ASSERT_MAIN_THREAD;

  ostringstream out;
  out << "Video system: " << SDL_GetCurrentVideoDriver() << '\n';
  SDL_RendererInfo info;
  if(SDL_GetRendererInfo(myRenderer, &info) >= 0)
  {
    out << "  Renderer: " << info.name << '\n';
    if(info.max_texture_width > 0 && info.max_texture_height > 0)
      out << "  Max texture: " << info.max_texture_width << "x"
                               << info.max_texture_height << '\n';
    out << "  Flags: "
        << ((info.flags & SDL_RENDERER_PRESENTVSYNC) ? "+" : "-") << "vsync, "
        << ((info.flags & SDL_RENDERER_ACCELERATED) ? "+" : "-") << "accel"
        << '\n';
  }
  return out.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::showCursor(bool show)
{
  ASSERT_MAIN_THREAD;

  SDL_ShowCursor(show ? SDL_ENABLE : SDL_DISABLE);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::grabMouse(bool grab)
{
  ASSERT_MAIN_THREAD;

  SDL_SetRelativeMouseMode(grab ? SDL_TRUE : SDL_FALSE);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FBBackendSDL2::fullScreen() const
{
  ASSERT_MAIN_THREAD;

#ifdef WINDOWED_SUPPORT
  return SDL_GetWindowFlags(myWindow) & SDL_WINDOW_FULLSCREEN_DESKTOP;
#else
  return true;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int FBBackendSDL2::refreshRate() const
{
  ASSERT_MAIN_THREAD;

  const uInt32 displayIndex = SDL_GetWindowDisplayIndex(myWindow);
  SDL_DisplayMode sdlMode;

  if(SDL_GetCurrentDisplayMode(displayIndex, &sdlMode) == 0)
    return sdlMode.refresh_rate;

  if(myWindow != nullptr)
    Logger::error("Could not retrieve current display mode");

  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::renderToScreen()
{
  ASSERT_MAIN_THREAD;

  // Show all changes made to the renderer
  SDL_RenderPresent(myRenderer);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::setWindowIcon()
{
#if !defined(BSPF_MACOS) && !defined(RETRON77)
#include "stella_icon.hxx"
  ASSERT_MAIN_THREAD;

  SDL_Surface* surface = SDL_CreateRGBSurfaceFrom(stella_icon, 32, 32, 32,
                         32 * 4, 0xFF0000, 0x00FF00, 0x0000FF, 0xFF000000);
  SDL_SetWindowIcon(myWindow, surface);
  SDL_FreeSurface(surface);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
unique_ptr<FBSurface> FBBackendSDL2::createSurface(
  uInt32 w,
  uInt32 h,
  ScalingInterpolation inter,
  const uInt32* data
) const
{
  return make_unique<FBSurfaceSDL2>
      (const_cast<FBBackendSDL2&>(*this), w, h, inter, data);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::readPixels(uInt8* buffer, size_t pitch,
                               const Common::Rect& rect) const
{
  ASSERT_MAIN_THREAD;

  SDL_Rect r;
  r.x = rect.x();  r.y = rect.y();
  r.w = rect.w();  r.h = rect.h();

  SDL_RenderReadPixels(myRenderer, &r, 0, buffer, static_cast<int>(pitch));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::clear()
{
  ASSERT_MAIN_THREAD;

  SDL_RenderClear(myRenderer);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::detectFeatures()
{
  myRenderTargetSupport = detectRenderTargetSupport();

  if(myRenderer && !myRenderTargetSupport)
    Logger::info("Render targets are not supported --- QIS not available");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FBBackendSDL2::detectRenderTargetSupport()
{
  ASSERT_MAIN_THREAD;

  if(myRenderer == nullptr)
    return false;

  SDL_RendererInfo info;
  SDL_GetRendererInfo(myRenderer, &info);

  if(!(info.flags & SDL_RENDERER_TARGETTEXTURE))
    return false;

  SDL_Texture* tex =
      SDL_CreateTexture(myRenderer, myPixelFormat->format,
                        SDL_TEXTUREACCESS_TARGET, 16, 16);

  if(!tex)
    return false;

  const int sdlError = SDL_SetRenderTarget(myRenderer, tex);
  SDL_SetRenderTarget(myRenderer, nullptr);

  SDL_DestroyTexture(tex);

  return sdlError == 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendSDL2::determineDimensions()
{
  ASSERT_MAIN_THREAD;

  SDL_GetWindowSize(myWindow, &myWindowW, &myWindowH);

  if(myRenderer == nullptr)
  {
    myRenderW = myWindowW;
    myRenderH = myWindowH;
  }
  else
    SDL_GetRendererOutputSize(myRenderer, &myRenderW, &myRenderH);
}
