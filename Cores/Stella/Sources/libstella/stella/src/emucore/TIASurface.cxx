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

#include "FBSurface.hxx"
#include "Settings.hxx"
#include "OSystem.hxx"
#include "Console.hxx"
#include "TIA.hxx"
#include "PNGLibrary.hxx"
#include "PaletteHandler.hxx"
#include "TIASurface.hxx"

namespace {
  ScalingInterpolation interpolationModeFromSettings(const Settings& settings)
  {
#ifdef RETRON77
  // Witv TV / and or scanline interpolation, the image has a height of ~480px. THe R77 runs at 720p, so there
  // is no benefit from QIS in y-direction. In addition, QIS on the R77 has performance issues if TV effects are
  // enabled.
  return settings.getBool("tia.inter") || settings.getInt("tv.filter") != 0
    ? ScalingInterpolation::blur
    : ScalingInterpolation::sharp;
#else
    return settings.getBool("tia.inter") ?
      ScalingInterpolation::blur :
      ScalingInterpolation::sharp;
#endif
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TIASurface::TIASurface(OSystem& system)
  : myOSystem{system},
    myFB{system.frameBuffer()}
{
  // Load NTSC filter settings
  NTSCFilter::loadConfig(myOSystem.settings());

  // Create a surface for the TIA image and scanlines; we'll need them eventually
  myTiaSurface = myFB.allocateSurface(
    AtariNTSC::outWidth(TIAConstants::frameBufferWidth),
    TIAConstants::frameBufferHeight,
    !correctAspect()
      ? ScalingInterpolation::none
      : interpolationModeFromSettings(myOSystem.settings())
  );

  // Base TIA surface for use in taking snapshots in 1x mode
  myBaseTiaSurface = myFB.allocateSurface(TIAConstants::frameBufferWidth*2,
                                          TIAConstants::frameBufferHeight);

  // Create shading surface
  static constexpr uInt32 data = 0xff000000;

  myShadeSurface = myFB.allocateSurface(1, 1, ScalingInterpolation::sharp, &data);

  FBSurface::Attributes& attr = myShadeSurface->attributes();

  attr.blending = true;
  attr.blendalpha = 35; // darken stopped emulation by 35%
  myShadeSurface->applyAttributes();

  myRGBFramebuffer.fill(0);

  // Enable/disable threading in the NTSC TV effects renderer
  myNTSCFilter.enableThreading(myOSystem.settings().getBool("threads"));

  myPaletteHandler = make_unique<PaletteHandler>(myOSystem);
  myPaletteHandler->loadConfig(myOSystem.settings());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TIASurface::~TIASurface()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::initialize(const Console& console,
                            const VideoModeHandler::Mode& mode)
{
  myTIA = &(console.tia());

  myTiaSurface->setDstPos(mode.imageR.x(), mode.imageR.y());
  myTiaSurface->setDstSize(mode.imageR.w(), mode.imageR.h());

  myPaletteHandler->setPalette();

  createScanlineSurface();
  setNTSC(static_cast<NTSCFilter::Preset>(myOSystem.settings().getInt("tv.filter")), false);

#if 0
cerr << "INITIALIZE:\n"
     << "TIA:\n"
     << "src: " << myTiaSurface->srcRect() << '\n'
     << "dst: " << myTiaSurface->dstRect() << "\n\n"
     << "SLine:\n"
     << "src: " << mySLineSurface->srcRect() << '\n'
     << "dst: " << mySLineSurface->dstRect() << "\n\n";
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::setPalette(const PaletteArray& tia_palette,
                            const PaletteArray& rgb_palette)
{
  myPalette = tia_palette;

  // The NTSC filtering needs access to the raw RGB data, since it calculates
  // its own internal palette
  myNTSCFilter.setPalette(rgb_palette);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FBSurface& TIASurface::baseSurface(Common::Rect& rect) const
{
  const uInt32 tiaw = myTIA->width(), width = tiaw * 2, height = myTIA->height();
  rect.setBounds(0, 0, width, height);

  // Fill the surface with pixels from the TIA, scaled 2x horizontally
  uInt32 *buf_ptr{nullptr}, pitch{0};
  myBaseTiaSurface->basePtr(buf_ptr, pitch);

  for(size_t y = 0; y < height; ++y)
    for(size_t x = 0; x < width; ++x)
        *buf_ptr++ = myPalette[*(myTIA->frameBuffer() + y * tiaw + x / 2)];

  return *myBaseTiaSurface;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 TIASurface::mapIndexedPixel(uInt8 indexedColor, uInt8 shift) const
{
  return myPalette[indexedColor | shift];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::setNTSC(NTSCFilter::Preset preset, bool show)
{
  ostringstream buf;
  if(preset == NTSCFilter::Preset::OFF)
  {
    enableNTSC(false);
    buf << "TV filtering disabled";
  }
  else
  {
    enableNTSC(true);
    const string& mode = myNTSCFilter.setPreset(preset);
    buf << "TV filtering (" << mode << " mode)";
  }
  myOSystem.settings().setValue("tv.filter", static_cast<int>(preset));

  if(show) myFB.showTextMessage(buf.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::changeNTSC(int direction)
{
  static constexpr std::array<NTSCFilter::Preset, 6> PRESETS = {
    NTSCFilter::Preset::OFF, NTSCFilter::Preset::RGB, NTSCFilter::Preset::SVIDEO,
    NTSCFilter::Preset::COMPOSITE, NTSCFilter::Preset::BAD, NTSCFilter::Preset::CUSTOM
  };
  int preset = myOSystem.settings().getInt("tv.filter");

  if(direction == +1)
  {
    if(preset == static_cast<int>(NTSCFilter::Preset::CUSTOM))
      preset = static_cast<int>(NTSCFilter::Preset::OFF);
    else
      preset++;
  }
  else if (direction == -1)
  {
    if(preset == static_cast<int>(NTSCFilter::Preset::OFF))
      preset = static_cast<int>(NTSCFilter::Preset::CUSTOM);
    else
      preset--;
  }
  setNTSC(PRESETS[preset], true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::setNTSCAdjustable(int direction)
{
  string text, valueText;
  Int32 value{0};

  setNTSC(NTSCFilter::Preset::CUSTOM);
  ntsc().selectAdjustable(direction, text, valueText, value);
  myOSystem.frameBuffer().showGaugeMessage(text, valueText, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::changeNTSCAdjustable(int adjustable, int direction)
{
  string text, valueText;
  Int32 newValue{0};

  setNTSC(NTSCFilter::Preset::CUSTOM);
  ntsc().changeAdjustable(adjustable, direction, text, valueText, newValue);
  NTSCFilter::saveConfig(myOSystem.settings());
  myOSystem.frameBuffer().showGaugeMessage(text, valueText, newValue);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::changeCurrentNTSCAdjustable(int direction)
{
  string text, valueText;
  Int32 newValue{0};

  setNTSC(NTSCFilter::Preset::CUSTOM);
  ntsc().changeCurrentAdjustable(direction, text, valueText, newValue);
  NTSCFilter::saveConfig(myOSystem.settings());
  myOSystem.frameBuffer().showGaugeMessage(text, valueText, newValue);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::changeScanlineIntensity(int direction)
{
  FBSurface::Attributes& attr = mySLineSurface->attributes();

  attr.blendalpha += direction * 2;
  attr.blendalpha = BSPF::clamp(static_cast<Int32>(attr.blendalpha), 0, 100);
  mySLineSurface->applyAttributes();

  const uInt32 intensity = attr.blendalpha;

  myOSystem.settings().setValue("tv.scanlines", intensity);
  enableNTSC(ntscEnabled());

  ostringstream buf;
  if(intensity)
    buf << intensity << "%";
  else
    buf << "Off";
  myFB.showGaugeMessage("Scanline intensity", buf.str(), intensity);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TIASurface::ScanlineMask TIASurface::scanlineMaskType(int direction)
{
  static constexpr
  std::array<string_view, static_cast<int>(ScanlineMask::NumMasks)> Masks = {
    SETTING_STANDARD,
    SETTING_THIN,
    SETTING_PIXELS,
    SETTING_APERTURE,
    SETTING_MAME
  };
  int i = 0;
  const string& name = myOSystem.settings().getString("tv.scanmask");

  for(const auto& mask: Masks)
  {
    if(mask == name)
    {
      if(direction)
      {
        i = BSPF::clampw(i + direction, 0, static_cast<int>(ScanlineMask::NumMasks) - 1);
        myOSystem.settings().setValue("tv.scanmask", Masks[i]);
      }
      return static_cast<ScanlineMask>(i);
    }
    ++i;
  }
  return ScanlineMask::Standard;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::cycleScanlineMask(int direction)
{
  static constexpr
  std::array<string_view, static_cast<int>(ScanlineMask::NumMasks)> Names = {
    "Standard",
    "Thin lines",
    "Pixelated",
    "Aperture Grille",
    "MAME"
  };
  const int i = static_cast<int>(scanlineMaskType(direction));

  if(direction)
    createScanlineSurface();

  ostringstream msg;

  msg << "Scanline data '" << Names[i] << "'";
  myOSystem.frameBuffer().showTextMessage(msg.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::enablePhosphor(bool enable, int blend)
{
  if(myPhosphorHandler.initialize(enable, blend))
  {
    myPBlend = blend;
    myFilter = static_cast<Filter>(
        enable ? static_cast<uInt8>(myFilter) | 0x01
               : static_cast<uInt8>(myFilter) & 0x10);
    myRGBFramebuffer.fill(0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::createScanlineSurface()
{
  // Idea: Emulate
  // - Dot-Trio Shadow-Mask
  // - Slot-Mask (NEC 'CromaClear')
  // - Aperture-Grille (Sony 'Trinitron')

  using Data = std::vector<std::vector<uInt32>>;

  struct Pattern
  {
    uInt32 vRepeats{1}; // number of vertically repeated data blocks (adding a bit of variation)
    Data   data;

    explicit Pattern(uInt32 c_vRepeats, const Data& c_data)
      : vRepeats(c_vRepeats), data(c_data)
    {}
  };
  static std::array<Pattern, static_cast<int>(ScanlineMask::NumMasks)> Patterns = {{
    Pattern(1,  // standard
    {
      { 0x00000000 },
      { 0xaa000000 } // 0xff decreased to 0xaa (67%) to match overall brightness of other pattern
    }),
    Pattern(1,  // thin
    {
      { 0x00000000 },
      { 0x00000000 },
      { 0xff000000 }
    }),
    Pattern(2,  // pixel
    {
      // orignal data from https://forum.arcadeotaku.com/posting.php?mode=quote&f=10&p=134359
      //{ 0x08ffffff, 0x02ffffff, 0x80e7e7e7 },
      //{ 0x08ffffff, 0x80e7e7e7, 0x40ffffff },
      //{ 0xff282828, 0xff282828, 0xff282828 },
      //{ 0x80e7e7e7, 0x04ffffff, 0x04ffffff },
      //{ 0x04ffffff, 0x80e7e7e7, 0x20ffffff },
      //{ 0xff282828, 0xff282828, 0xff282828 },
      // same but using RGB = 0,0,0
      //{ 0x08000000, 0x02000000, 0x80000000 },
      //{ 0x08000000, 0x80000000, 0x40000000 },
      //{ 0xff000000, 0xff000000, 0xff000000 },
      //{ 0x80000000, 0x04000000, 0x04000000 },
      //{ 0x04000000, 0x80000000, 0x20000000 },
      //{ 0xff000000, 0xff000000, 0xff000000 },
      // brightened
      { 0x06000000, 0x01000000, 0x5a000000 },
      { 0x06000000, 0x5a000000, 0x3d000000 },
      { 0xb4000000, 0xb4000000, 0xb4000000 },
      { 0x5a000000, 0x03000000, 0x03000000 },
      { 0x03000000, 0x5a000000, 0x17000000 },
      { 0xb4000000, 0xb4000000, 0xb4000000 }
    }),
    Pattern(1,  // aperture
    {
      //{ 0x2cf31d00, 0x1500ffce, 0x1c1200a4 },
      //{ 0x557e0f00, 0x40005044, 0x45070067 },
      //{ 0x800c0200, 0x89000606, 0x8d02000d },
      // (doubled & darkened, alpha */ 1.75)
      { 0x19f31d00, 0x0c00ffce, 0x101200a4, 0x19f31d00, 0x0c00ffce, 0x101200a4 },
      { 0x317e0f00, 0x25005044, 0x37070067, 0x317e0f00, 0x25005044, 0x37070067 },
      { 0xe00c0200, 0xf0000606, 0xf702000d, 0xe00c0200, 0xf0000606, 0xf702000d },
    }),
    Pattern(3,  // mame
    {
      // original tile data from https://wiki.arcadeotaku.com/w/MAME_CRT_Simulation
      //{ 0xffb4b4b4, 0xffa5a5a5, 0xffc3c3c3 },
      //{ 0xffffffff, 0xfff0f0f0, 0xfff0f0f0 },
      //{ 0xfff0f0f0, 0xffffffff, 0xffe1e1e1 },
      //{ 0xff000000, 0xff000000, 0xff000000 },
      //{ 0xffa5a5a5, 0xffc3c3c3, 0xffb4b4b4 },
      //{ 0xfff0f0f0, 0xfff0f0f0, 0xffffffff },
      //{ 0xffffffff, 0xffe1e1e1, 0xfff0f0f0 },
      //{ 0xff000000, 0xff000000, 0xff000000 },
      //{ 0xffc3c3c3, 0xffb4b4b4, 0xffa5a5a5 },
      //{ 0xfff0f0f0, 0xffffffff, 0xfff0f0f0 },
      //{ 0xffe1e1e1, 0xfff0f0f0, 0xffffffff },
      //{ 0xff000000, 0xff000000, 0xff000000 },
      // MAME tile RGB values inverted into alpha channel
      { 0x4b000000, 0x5a000000, 0x3c000000 },
      { 0x00000000, 0x0f000000, 0x0f000000 },
      { 0x0f000000, 0x00000000, 0x1e000000 },
      { 0xff000000, 0xff000000, 0xff000000 },
      { 0x5a000000, 0x3c000000, 0x4b000000 },
      { 0x0f000000, 0x0f000000, 0x00000000 },
      { 0x00000000, 0x1e000000, 0x0f000000 },
      { 0xff000000, 0xff000000, 0xff000000 },
      { 0x3c000000, 0x4b000000, 0x5a000000 },
      { 0x0f000000, 0x00000000, 0x0f000000 },
      { 0x1e000000, 0x0f000000, 0x00000000 },
      { 0xff000000, 0xff000000, 0xff000000 },
    }),
  }};
  const auto mask = static_cast<int>(scanlineMaskType());
  const auto pWidth = static_cast<uInt32>(Patterns[mask].data[0].size());
  const auto pHeight = static_cast<uInt32>(Patterns[mask].data.size() / Patterns[mask].vRepeats);
  const uInt32 vRepeats = Patterns[mask].vRepeats;
  // Single width pattern need no horizontal repeats
  const uInt32 width = pWidth > 1 ? TIAConstants::frameBufferWidth * pWidth : 1;
  // TODO: Idea, alternative mask pattern if destination is scaled smaller than mask height?
  const uInt32 height = myTIA->height()* pHeight; // vRepeats are not used here
  // Copy repeated pattern into surface data
  std::vector<uInt32> data(static_cast<size_t>(width) * height);

  for(uInt32 i = 0; i < width * height; ++i)
    data[i] = Patterns[mask].data[(i / width) % (pHeight * vRepeats)][i % pWidth];

  myFB.deallocateSurface(mySLineSurface);
  mySLineSurface = myFB.allocateSurface(width, height,
    interpolationModeFromSettings(myOSystem.settings()), data.data());

  //mySLineSurface->setSrcSize(mySLineSurface->width(), height);
  mySLineSurface->setDstRect(myTiaSurface->dstRect());
  updateSurfaceSettings();

  enableNTSC(ntscEnabled());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::enableNTSC(bool enable)
{
  myFilter = static_cast<Filter>(
      enable ? static_cast<uInt8>(myFilter) | 0x10
             : static_cast<uInt8>(myFilter) & 0x01);

  const uInt32 surfaceWidth = enable ?
    AtariNTSC::outWidth(TIAConstants::frameBufferWidth) : TIAConstants::frameBufferWidth;

  if (surfaceWidth != myTiaSurface->srcRect().w() || myTIA->height() != myTiaSurface->srcRect().h()) {
    myTiaSurface->setSrcSize(surfaceWidth, myTIA->height());

    myTiaSurface->invalidate();
  }

  // Generate a scanline surface from current scanline pattern
  // Apply current blend to scan line surface
  myScanlinesEnabled = myOSystem.settings().getInt("tv.scanlines") > 0;
  FBSurface::Attributes& sl_attr = mySLineSurface->attributes();
  sl_attr.blending = myScanlinesEnabled;
  sl_attr.blendalpha = myOSystem.settings().getInt("tv.scanlines");
  mySLineSurface->applyAttributes();

  myRGBFramebuffer.fill(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIASurface::effectsInfo() const
{
  const FBSurface::Attributes& attr = mySLineSurface->attributes();
  ostringstream buf;

  switch(myFilter)
  {
    case Filter::Normal:
      buf << "Disabled, normal mode";
      break;
    case Filter::Phosphor:
      buf << "Disabled, phosphor=" << myPBlend;
      break;
    case Filter::BlarggNormal:
      buf << myNTSCFilter.getPreset();
      break;
    case Filter::BlarggPhosphor:
      buf << myNTSCFilter.getPreset() << ", phosphor=" << myPBlend;
      break;
  }
  if(attr.blendalpha)
    buf << ", scanlines=" << attr.blendalpha
      << "/" << myOSystem.settings().getString("tv.scanmask");
  buf << ", inter=" << (myOSystem.settings().getBool("tia.inter") ? "enabled" : "disabled");
  buf << ", aspect correction=" << (correctAspect() ? "enabled" : "disabled");
  buf << ", palette=" << myOSystem.settings().getString("palette");

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline uInt32 TIASurface::averageBuffers(uInt32 bufOfs)
{
  const uInt32 c = myRGBFramebuffer[bufOfs];
  const uInt32 p = myPrevRGBFramebuffer[bufOfs];

  // Split into RGB values
  const auto rc = static_cast<uInt8>(c >> 16),
             gc = static_cast<uInt8>(c >> 8),
             bc = static_cast<uInt8>(c),
             rp = static_cast<uInt8>(p >> 16),
             gp = static_cast<uInt8>(p >> 8),
             bp = static_cast<uInt8>(p);

  // Mix current calculated buffer with previous calculated buffer (50:50)
  const uInt8 rn = (rc + rp) / 2;
  const uInt8 gn = (gc + gp) / 2;
  const uInt8 bn = (bc + bp) / 2;

  // return averaged value
  return (rn << 16) | (gn << 8) | bn;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::render(bool shade)
{
  const uInt32 width = myTIA->width(), height = myTIA->height();

  uInt32 *out{nullptr}, outPitch{0};
  myTiaSurface->basePtr(out, outPitch);

  switch(myFilter)
  {
    case Filter::Normal:
    {
      const uInt8* tiaIn = myTIA->frameBuffer();

      uInt32 bufofs = 0, screenofsY = 0;
      for(uInt32 y = 0; y < height; ++y)
      {
        uInt32 pos = screenofsY;
        for (uInt32 x = width / 2; x; --x)
        {
          out[pos++] = myPalette[tiaIn[bufofs++]];
          out[pos++] = myPalette[tiaIn[bufofs++]];
        }
        screenofsY += outPitch;
      }
      break;
    }

    case Filter::Phosphor:
    {
      const uInt8* tiaIn = myTIA->frameBuffer();
      uInt32* rgbIn = myRGBFramebuffer.data();

      if (mySaveSnapFlag)
        std::copy_n(myRGBFramebuffer.begin(), width * height,
                    myPrevRGBFramebuffer.begin());

      uInt32 bufofs = 0, screenofsY = 0;
      for(uInt32 y = height; y ; --y)
      {
        uInt32 pos = screenofsY;
        for(uInt32 x = width / 2; x ; --x)
        {
          // Store back into displayed frame buffer (for next frame)
          rgbIn[bufofs] = out[pos++] = PhosphorHandler::getPixel(myPalette[tiaIn[bufofs]], rgbIn[bufofs]);
          ++bufofs;
          rgbIn[bufofs] = out[pos++] = PhosphorHandler::getPixel(myPalette[tiaIn[bufofs]], rgbIn[bufofs]);
          ++bufofs;
        }
        screenofsY += outPitch;
      }
      break;
    }

    case Filter::BlarggNormal:
    {
      myNTSCFilter.render(myTIA->frameBuffer(), width, height, out, outPitch << 2);
      break;
    }

    case Filter::BlarggPhosphor:
    {
      if(mySaveSnapFlag)
        std::copy_n(myRGBFramebuffer.begin(), height * outPitch,
                    myPrevRGBFramebuffer.begin());

      myNTSCFilter.render(myTIA->frameBuffer(), width, height, out, outPitch << 2, myRGBFramebuffer.data());
      break;
    }
  }

  // Draw TIA image
  myTiaSurface->render();

  // Draw overlaying scanlines
  if(myScanlinesEnabled)
    mySLineSurface->render();

  if(shade)
  {
    myShadeSurface->setDstRect(myTiaSurface->dstRect());
    myShadeSurface->render();
  }

  if(mySaveSnapFlag)
  {
    mySaveSnapFlag = false;
  #ifdef IMAGE_SUPPORT
    myOSystem.png().takeSnapshot();
  #endif
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::renderForSnapshot()
{
  // TODO: This is currently called from PNGLibrary::takeSnapshot() only
  // Therefore the code could be simplified.
  // At some point, we will probably merge some of the functionality.
  // Furthermore, toggling the variable 'mySaveSnapFlag' in different places
  // is brittle, especially since rendering can happen in a different thread.

  const uInt32 width = myTIA->width(), height = myTIA->height();
  uInt32 pos{0};
  uInt32 *outPtr{nullptr}, outPitch{0};
  myTiaSurface->basePtr(outPtr, outPitch);

  mySaveSnapFlag = false;
  switch (myFilter)
  {
    // For non-phosphor modes, render the frame again
    case Filter::Normal:
    case Filter::BlarggNormal:
      render();
      break;

    // For phosphor modes, copy the phosphor framebuffer
    case Filter::Phosphor:
    {
      uInt32 bufofs = 0, screenofsY = 0;
      for(uInt32 y = height; y; --y)
      {
        pos = screenofsY;
        for(uInt32 x = width / 2; x; --x)
        {
          outPtr[pos++] = averageBuffers(bufofs++);
          outPtr[pos++] = averageBuffers(bufofs++);
        }
        screenofsY += outPitch;
      }
      break;
    }

    case Filter::BlarggPhosphor:
      uInt32 bufofs = 0;
      for(uInt32 y = height; y; --y)
        for(uInt32 x = outPitch; x; --x)
          outPtr[pos++] = averageBuffers(bufofs++);
      break;
  }

  if(myPhosphorHandler.phosphorEnabled())
  {
    // Draw TIA image
    myTiaSurface->render();

    // Draw overlaying scanlines
    if(myScanlinesEnabled)
      mySLineSurface->render();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIASurface::updateSurfaceSettings()
{
  if(myTiaSurface != nullptr)
    myTiaSurface->setScalingInterpolation(
      interpolationModeFromSettings(myOSystem.settings()));

  if(mySLineSurface != nullptr)
    mySLineSurface->setScalingInterpolation(
      interpolationModeFromSettings(myOSystem.settings()));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIASurface::correctAspect() const
{
  return myOSystem.settings().getBool("tia.correct_aspect");
}
