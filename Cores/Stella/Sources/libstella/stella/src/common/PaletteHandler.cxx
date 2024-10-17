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

#include "Console.hxx"
#include "FrameBuffer.hxx"

#include "PaletteHandler.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteHandler::PaletteHandler(OSystem& system)
  : myOSystem{system}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteHandler::PaletteType PaletteHandler::toPaletteType(string_view name) const
{
  if(name == SETTING_Z26)
    return PaletteType::Z26;

  if(name == SETTING_USER && myUserPaletteDefined)
    return PaletteType::User;

  if(name == SETTING_CUSTOM)
    return PaletteType::Custom;

  return PaletteType::Standard;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string_view PaletteHandler::toPaletteName(PaletteType type)
{
  static constexpr std::array<string_view, PaletteType::NumTypes> SETTING_NAMES = {
    SETTING_STANDARD, SETTING_Z26, SETTING_USER, SETTING_CUSTOM
  };

  return SETTING_NAMES[type];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::cyclePalette(int direction)
{
  static constexpr std::array<string_view, PaletteType::NumTypes> MESSAGES = {
    "Standard Stella", "Z26", "User-defined", "Custom"
  };
  int type = toPaletteType(myOSystem.settings().getString("palette"));

  do {
    type = BSPF::clampw(type + direction,
        static_cast<int>(PaletteType::MinType), static_cast<int>(PaletteType::MaxType));
  } while(type == PaletteType::User && !myUserPaletteDefined);

  const string_view palette = toPaletteName(static_cast<PaletteType>(type));
  const string message = string{MESSAGES[type]} + " palette";

  myOSystem.frameBuffer().showTextMessage(message);

  setPalette(palette);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PaletteHandler::isCustomAdjustable() const
{
  return myCurrentAdjustable <= CUSTOM_END;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PaletteHandler::isPhaseShift() const
{
  return myCurrentAdjustable == PHASE_SHIFT;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PaletteHandler::isRGBScale() const
{
  return myCurrentAdjustable >= RED_SCALE && myCurrentAdjustable <= BLUE_SCALE;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PaletteHandler::isRGBShift() const
{
  return myCurrentAdjustable >= RED_SHIFT && myCurrentAdjustable <= BLUE_SHIFT;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::showAdjustableMessage()
{
  ostringstream msg, buf;

  msg << "Palette " << myAdjustables[myCurrentAdjustable].name;
  if(isPhaseShift())
  {
    const ConsoleTiming timing = myOSystem.console().timing();
    const bool isNTSC = timing == ConsoleTiming::ntsc;
    const float value =
        myOSystem.console().timing() == ConsoleTiming::pal ? myPhasePAL : myPhaseNTSC;
    buf << std::fixed << std::setprecision(1) << value << DEGREE;
    myOSystem.frameBuffer().showGaugeMessage(
        "Palette phase shift", buf.str(), value,
        (isNTSC ? DEF_NTSC_SHIFT : DEF_PAL_SHIFT) - MAX_PHASE_SHIFT,
        (isNTSC ? DEF_NTSC_SHIFT : DEF_PAL_SHIFT) + MAX_PHASE_SHIFT);
  }
  else if(isRGBShift())
  {
    const float value = *myAdjustables[myCurrentAdjustable].value;

    buf << std::fixed << std::setprecision(1) << value << DEGREE;
    myOSystem.frameBuffer().showGaugeMessage(
      msg.str(), buf.str(), value, -MAX_RGB_SHIFT, +MAX_RGB_SHIFT);
  }
  else
  {
    const int value = isRGBScale()
      ? scaleRGBTo100(*myAdjustables[myCurrentAdjustable].value)
      : scaleTo100(*myAdjustables[myCurrentAdjustable].value);
    buf << value << "%";
    myOSystem.frameBuffer().showGaugeMessage(
      msg.str(), buf.str(), value);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::cycleAdjustable(int direction)
{
  const bool isCustomPalette =
      SETTING_CUSTOM == myOSystem.settings().getString("palette");
  bool isCustomAdj = false;

  do {
    myCurrentAdjustable = BSPF::clampw(static_cast<int>(myCurrentAdjustable + direction), 0,
        NUM_ADJUSTABLES - 1);
    isCustomAdj = isCustomAdjustable();
    // skip phase shift when 'Custom' palette is not selected
    if(!direction && isCustomAdj && !isCustomPalette)
      myCurrentAdjustable++;
  } while(isCustomAdj && !isCustomPalette);

  showAdjustableMessage();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::changeAdjustable(int adjustable, int direction)
{
  myCurrentAdjustable = adjustable;
  changeCurrentAdjustable(direction);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::changeCurrentAdjustable(int direction)
{
  if(isPhaseShift())
    changeColorPhaseShift(direction);
  else
  {
    if(isRGBScale())
    {
      int newVal = scaleRGBTo100(*myAdjustables[myCurrentAdjustable].value);

      newVal = BSPF::clamp(newVal + direction * 1, 0, 100);
      *myAdjustables[myCurrentAdjustable].value = scaleRGBFrom100(newVal);
    }
    else if(isRGBShift())
    {
      float newShift = *myAdjustables[myCurrentAdjustable].value;

      newShift = BSPF::clamp(newShift + direction * 0.5F, -MAX_RGB_SHIFT, MAX_RGB_SHIFT);
      *myAdjustables[myCurrentAdjustable].value = newShift;
    }
    else
    {
      int newVal = scaleTo100(*myAdjustables[myCurrentAdjustable].value);

      newVal = BSPF::clamp(newVal + direction * 1, 0, 100);
      *myAdjustables[myCurrentAdjustable].value = scaleFrom100(newVal);
    }
    showAdjustableMessage();
    setPalette();
  }
  saveConfig(myOSystem.settings());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::changeColorPhaseShift(int direction)
{
  const ConsoleTiming timing = myOSystem.console().timing();

  // SECAM is not supported
  if(timing != ConsoleTiming::secam)
  {
    const bool isNTSC = timing == ConsoleTiming::ntsc;
    const float shift = isNTSC ? DEF_NTSC_SHIFT : DEF_PAL_SHIFT;
    float newPhase = isNTSC ? myPhaseNTSC : myPhasePAL;

    newPhase = BSPF::clamp(newPhase + direction * 0.3F, shift - MAX_PHASE_SHIFT, shift + MAX_PHASE_SHIFT);

    if(isNTSC)
      myPhaseNTSC = newPhase;
    else
      myPhasePAL = newPhase;

    generateCustomPalette(timing);
    setPalette(SETTING_CUSTOM);

    showAdjustableMessage();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::loadConfig(const Settings& settings)
{
  // Load adjustables
  myPhaseNTSC   = BSPF::clamp(settings.getFloat("pal.phase_ntsc"),
                              DEF_NTSC_SHIFT - MAX_PHASE_SHIFT, DEF_NTSC_SHIFT + MAX_PHASE_SHIFT);
  myPhasePAL    = BSPF::clamp(settings.getFloat("pal.phase_pal"),
                              DEF_PAL_SHIFT - MAX_PHASE_SHIFT, DEF_PAL_SHIFT + MAX_PHASE_SHIFT);
  myRedScale    = BSPF::clamp(settings.getFloat("pal.red_scale"),   -1.0F, 1.0F) + 1.F;
  myGreenScale  = BSPF::clamp(settings.getFloat("pal.green_scale"), -1.0F, 1.0F) + 1.F;
  myBlueScale   = BSPF::clamp(settings.getFloat("pal.blue_scale"),  -1.0F, 1.0F) + 1.F;
  myRedShift    = BSPF::clamp(settings.getFloat("pal.red_shift"),   -MAX_RGB_SHIFT, MAX_RGB_SHIFT);
  myGreenShift  = BSPF::clamp(settings.getFloat("pal.green_shift"), -MAX_RGB_SHIFT, MAX_RGB_SHIFT);
  myBlueShift   = BSPF::clamp(settings.getFloat("pal.blue_shift"),  -MAX_RGB_SHIFT, MAX_RGB_SHIFT);

  myHue         = BSPF::clamp(settings.getFloat("pal.hue"),         -1.0F, 1.0F);
  mySaturation  = BSPF::clamp(settings.getFloat("pal.saturation"),  -1.0F, 1.0F);
  myContrast    = BSPF::clamp(settings.getFloat("pal.contrast"),    -1.0F, 1.0F);
  myBrightness  = BSPF::clamp(settings.getFloat("pal.brightness"),  -1.0F, 1.0F);
  myGamma       = BSPF::clamp(settings.getFloat("pal.gamma"),       -1.0F, 1.0F);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::saveConfig(Settings& settings) const
{
  // Save adjustables
  settings.setValue("pal.phase_ntsc", myPhaseNTSC);
  settings.setValue("pal.phase_pal", myPhasePAL);
  settings.setValue("pal.red_scale", myRedScale - 1.F);
  settings.setValue("pal.green_scale", myGreenScale - 1.F);
  settings.setValue("pal.blue_scale", myBlueScale - 1.F);
  settings.setValue("pal.red_shift", myRedShift);
  settings.setValue("pal.green_shift", myGreenShift);
  settings.setValue("pal.blue_shift", myBlueShift);

  settings.setValue("pal.hue", myHue);
  settings.setValue("pal.saturation", mySaturation);
  settings.setValue("pal.contrast", myContrast);
  settings.setValue("pal.brightness", myBrightness);
  settings.setValue("pal.gamma", myGamma);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::setAdjustables(const Adjustable& adjustable)
{
  myPhaseNTSC   = scaleFromAngles(adjustable.phaseNtsc);
  myPhasePAL    = scaleFromAngles(adjustable.phasePal);
  myRedScale    = scaleRGBFrom100(adjustable.redScale);
  myGreenScale  = scaleRGBFrom100(adjustable.greenScale);
  myBlueScale   = scaleRGBFrom100(adjustable.blueScale);
  myRedShift    = scaleFromAngles(adjustable.redShift);
  myGreenShift  = scaleFromAngles(adjustable.greenShift);
  myBlueShift   = scaleFromAngles(adjustable.blueShift);

  myHue         = scaleFrom100(adjustable.hue);
  mySaturation  = scaleFrom100(adjustable.saturation);
  myContrast    = scaleFrom100(adjustable.contrast);
  myBrightness  = scaleFrom100(adjustable.brightness);
  myGamma       = scaleFrom100(adjustable.gamma);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::getAdjustables(Adjustable& adjustable) const
{
  adjustable.phaseNtsc   = scaleToAngles(myPhaseNTSC);
  adjustable.phasePal    = scaleToAngles(myPhasePAL);
  adjustable.redScale    = scaleRGBTo100(myRedScale);
  adjustable.greenScale  = scaleRGBTo100(myGreenScale);
  adjustable.blueScale   = scaleRGBTo100(myBlueScale);
  adjustable.redShift    = scaleToAngles(myRedShift);
  adjustable.greenShift  = scaleToAngles(myGreenShift);
  adjustable.blueShift   = scaleToAngles(myBlueShift);

  adjustable.hue         = scaleTo100(myHue);
  adjustable.saturation  = scaleTo100(mySaturation);
  adjustable.contrast    = scaleTo100(myContrast);
  adjustable.brightness  = scaleTo100(myBrightness);
  adjustable.gamma       = scaleTo100(myGamma);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::setPalette(string_view name)
{
  myOSystem.settings().setValue("palette", name);

  setPalette();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::setPalette()
{
  if(myOSystem.hasConsole())
  {
    const string& name = myOSystem.settings().getString("palette");

    // Load user-defined palette for this ROM
    if(name == SETTING_USER)
      loadUserPalette();

    // Look at all the palettes, since we don't know which one is
    // currently active
    static constexpr BSPF::array2D<const PaletteArray*, PaletteType::NumTypes,
    static_cast<int>(ConsoleTiming::numTimings)> palettes = {{
      { &ourNTSCPalette,       &ourPALPalette,       &ourSECAMPalette     },
      { &ourNTSCPaletteZ26,    &ourPALPaletteZ26,    &ourSECAMPaletteZ26  },
      { &ourUserNTSCPalette,   &ourUserPALPalette,   &ourUserSECAMPalette },
      { &ourCustomNTSCPalette, &ourCustomPALPalette, &ourSECAMPalette     }
    }};
    // See which format we should be using
    const ConsoleTiming timing = myOSystem.console().timing();
    const PaletteType paletteType = toPaletteType(name);
    // Now consider the current display format
    const PaletteArray* palette = palettes[paletteType][static_cast<int>(timing)];

    if(paletteType == PaletteType::Custom)
      generateCustomPalette(timing);

    myOSystem.frameBuffer().setTIAPalette(adjustedPalette(*palette));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteArray PaletteHandler::adjustedPalette(const PaletteArray& palette) const
{
  PaletteArray destPalette{0};
  // Constants for saturation and gray scale calculation
  constexpr float PR = .2989F;
  constexpr float PG = .5870F;
  constexpr float PB = .1140F;
  // Generate adjust table
  constexpr int ADJUST_SIZE = 256;
  constexpr int RGB_UNIT = 1 << 8;
  constexpr float RGB_OFFSET = 0.5F;
  const float hue = myHue;
  const float brightness = myBrightness * (0.5F * RGB_UNIT) + RGB_OFFSET;
  const float contrast = myContrast * (0.5F * RGB_UNIT) + RGB_UNIT;
  const float saturation = mySaturation + 1;
  const float gamma = 1.1333F - myGamma * 0.5F;
  /* match common PC's 2.2 gamma to TV's 2.65 gamma */
  constexpr float toFloat = 1.F / (ADJUST_SIZE - 1);
  std::array<float, ADJUST_SIZE> adjust{0};

  for(int i = 0; i < ADJUST_SIZE; i++)
    adjust[i] = powf(i * toFloat, gamma) * contrast + brightness;

  // Transform original palette into destination palette
  for(size_t i = 0; i < destPalette.size(); i += 2)
  {
    const uInt32 pixel = palette[i];
    int r = (pixel >> 16) & 0xff;
    int g = (pixel >> 8)  & 0xff;
    int b = (pixel >> 0)  & 0xff;

    // adjust hue (different for NTSC and PAL?) and saturation
    adjustHueSaturation(r, g, b, hue, saturation);

    // adjust contrast, brightness, gamma
    r = adjust[r];
    g = adjust[g];
    b = adjust[b];

    r = BSPF::clamp(r, 0, 255);
    g = BSPF::clamp(g, 0, 255);
    b = BSPF::clamp(b, 0, 255);

    destPalette[i] = (r << 16) + (g << 8) + b;

    // Fill the odd numbered palette entries with gray values (calculated
    // using the standard RGB -> grayscale conversion formula)
    // Used for PAL color-loss data and 'greying out' the frame in the debugger.
    const auto lum = static_cast<uInt8>((r * PR) + (g * PG) + (b * PB));

    destPalette[i + 1] = (lum << 16) + (lum << 8) + lum;
  }
  return destPalette;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::loadUserPalette()
{
  if (!myOSystem.checkUserPalette(true))
    return;

  ByteBuffer in;
  try        { myOSystem.paletteFile().read(in); }
  catch(...) { return; }

  uInt8* pixbuf = in.get();
  for(int i = 0; i < 128; i++, pixbuf += 3)  // NTSC palette
  {
    const uInt32 pixel = (static_cast<int>(pixbuf[0]) << 16) +
                         (static_cast<int>(pixbuf[1]) << 8)  +
                          static_cast<int>(pixbuf[2]);
    ourUserNTSCPalette[(i<<1)] = pixel;
  }
  for(int i = 0; i < 128; i++, pixbuf += 3)  // PAL palette
  {
    const uInt32 pixel = (static_cast<int>(pixbuf[0]) << 16) +
                         (static_cast<int>(pixbuf[1]) << 8)  +
                          static_cast<int>(pixbuf[2]);
    ourUserPALPalette[(i<<1)] = pixel;
  }

  std::array<uInt32, 16> secam{0};  // All 8 24-bit pixels, plus 8 colorloss pixels
  for(int i = 0; i < 8; i++, pixbuf += 3)    // SECAM palette
  {
    const uInt32 pixel = (static_cast<int>(pixbuf[0]) << 16) +
                         (static_cast<int>(pixbuf[1]) << 8)  +
                          static_cast<int>(pixbuf[2]);
    secam[(i<<1)]   = pixel;
    secam[(i<<1)+1] = 0;
  }
  uInt32* ptr = ourUserSECAMPalette.data();
  for(int i = 0; i < 16; ++i)
  {
    const uInt32* s = secam.data();
    for(int j = 0; j < 16; ++j)
      *ptr++ = *s++;
  }

  myUserPaletteDefined = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::generateCustomPalette(ConsoleTiming timing) const
{
  constexpr int NUM_CHROMA = 16;
  constexpr int NUM_LUMA = 8;
  constexpr float SATURATION = 0.25F; // default saturation

  if(timing == ConsoleTiming::ntsc)
  {
    vector2d IQ[NUM_CHROMA];
    // YIQ is YUV shifted by 33 degrees
    constexpr float offset = 33 * BSPF::PI_f / 180;
    const float shift = myPhaseNTSC * BSPF::PI_f / 180;

    // color 0 is grayscale
    for(int chroma = 1; chroma < NUM_CHROMA; chroma++)
    {
      IQ[chroma] = vector2d(SATURATION * sinf(offset + shift * (chroma - 1)),
                            SATURATION * cosf(offset + shift * (chroma - 1) - BSPF::PI_f));
    }
    const vector2d IQR = scale(rotate(vector2d(+0.956F, +0.621F), myRedShift),   myRedScale);
    const vector2d IQG = scale(rotate(vector2d(-0.272F, -0.647F), myGreenShift), myGreenScale);
    const vector2d IQB = scale(rotate(vector2d(-1.106F, +1.703F), myBlueShift),  myBlueScale);

    for(int chroma = 0; chroma < NUM_CHROMA; chroma++)
    {
      for(int luma = 0; luma < NUM_LUMA; luma++)
      {
        const float Y = 0.05F + luma / 8.24F; // 0.05..~0.90

        float R = Y + dotProduct(IQ[chroma], IQR);
        float G = Y + dotProduct(IQ[chroma], IQG);
        float B = Y + dotProduct(IQ[chroma], IQB);

        if(R < 0) R = 0;
        if(G < 0) G = 0;
        if(B < 0) B = 0;

        R = powf(R, 0.9F);
        G = powf(G, 0.9F);
        B = powf(B, 0.9F);

        const int r = BSPF::clamp(R * 255.F, 0.F, 255.F),
                  g = BSPF::clamp(G * 255.F, 0.F, 255.F),
                  b = BSPF::clamp(B * 255.F, 0.F, 255.F);

        ourCustomNTSCPalette[(chroma * NUM_LUMA + luma) << 1] = (r << 16) + (g << 8) + b;
      }
    }
  }
  else if(timing == ConsoleTiming::pal)
  {
    constexpr float offset = BSPF::PI_f;
    const float shift = myPhasePAL * BSPF::PI_f / 180;
    constexpr float fixedShift = 22.5F * BSPF::PI_f / 180;
    vector2d UV[NUM_CHROMA];

    // colors 0, 1, 14 and 15 are grayscale
    for(int chroma = 2; chroma < NUM_CHROMA - 2; chroma++)
    {
      const int idx = NUM_CHROMA - 1 - chroma;

      UV[idx].x = SATURATION * sinf(offset - fixedShift * chroma);
      if ((idx & 1) == 0)
        UV[idx].y = SATURATION * sinf(offset - shift * (chroma - 3.5F) / 2.F);
      else
        UV[idx].y = SATURATION * -sinf(offset - shift * chroma / 2.F);
    }
    // Most sources
    const vector2d UVR = scale(rotate(vector2d( 0.000F, +1.403F), myRedShift),   myRedScale);
    const vector2d UVG = scale(rotate(vector2d(-0.344F, -0.714F), myGreenShift), myGreenScale);
    const vector2d UVB = scale(rotate(vector2d(+0.714F,  0.000F), myBlueShift),  myBlueScale);
    // German Wikipedia, huh???
    //float R = Y + 1 / 0.877 * V;
    //float B = Y + 1 / 0.493 * U;
    //float G = 1.704 * Y - 0.590 * R - 0.194 * B;

    for(int chroma = 0; chroma < NUM_CHROMA; chroma++)
    {
      for(int luma = 0; luma < NUM_LUMA; luma++)
      {
        const float Y = 0.05F + luma / 8.24F; // 0.05..~0.90

        float R = Y + dotProduct(UV[chroma], UVR);
        float G = Y + dotProduct(UV[chroma], UVG);
        float B = Y + dotProduct(UV[chroma], UVB);

        if(R < 0) R = 0.0;
        if(G < 0) G = 0.0;
        if(B < 0) B = 0.0;

        R = powf(R, 1.2F);
        G = powf(G, 1.2F);
        B = powf(B, 1.2F);

        const int r = BSPF::clamp(R * 255.F, 0.F, 255.F),
                  g = BSPF::clamp(G * 255.F, 0.F, 255.F),
                  b = BSPF::clamp(B * 255.F, 0.F, 255.F);

        ourCustomPALPalette[(chroma * NUM_LUMA + luma) << 1] = (r << 16) + (g << 8) + b;
      }
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaletteHandler::adjustHueSaturation(int& R, int& G, int& B, float H, float S)
{
  // Adapted from http://beesbuzz.biz/code/16-hsv-color-transforms
  // (C) J. Fluffy Shagam
  // License: CC BY-SA 4.0
  const float su = S * cosf(-H * BSPF::PI_f);
  const float sw = S * sinf(-H * BSPF::PI_f);
  const float r = (.299F + .701F * su + .168F * sw) * R
                + (.587F - .587F * su + .330F * sw) * G
                + (.114F - .114F * su - .497F * sw) * B;
  const float g = (.299F - .299F * su - .328F * sw) * R
                + (.587F + .413F * su + .035F * sw) * G
                + (.114F - .114F * su + .292F * sw) * B;
  const float b = (.299F - .300F * su + 1.25F * sw) * R
                + (.587F - .588F * su - 1.05F * sw) * G
                + (.114F + .886F * su - .203F * sw) * B;

  R = BSPF::clamp(r, 0.F, 255.F);
  G = BSPF::clamp(g, 0.F, 255.F);
  B = BSPF::clamp(b, 0.F, 255.F);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteHandler::vector2d
PaletteHandler::rotate(const PaletteHandler::vector2d& vec, float angle)
{
  const float r = angle * BSPF::PI_f / 180;

  return PaletteHandler::vector2d(vec.x * cosf(r) - vec.y * sinf(r),
                                  vec.x * sinf(r) + vec.y * cosf(r));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteHandler::vector2d
PaletteHandler::scale(const PaletteHandler::vector2d& vec, float factor)
{
  return PaletteHandler::vector2d(vec.x * factor, vec.y * factor);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
float PaletteHandler::dotProduct(const PaletteHandler::vector2d& vec1,
                                 const PaletteHandler::vector2d& vec2)
{
  return vec1.x * vec2.x + vec1.y * vec2.y;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const PaletteArray PaletteHandler::ourNTSCPalette = {
  0x000000, 0, 0x4a4a4a, 0, 0x6f6f6f, 0, 0x8e8e8e, 0,
  0xaaaaaa, 0, 0xc0c0c0, 0, 0xd6d6d6, 0, 0xececec, 0,
  0x484800, 0, 0x69690f, 0, 0x86861d, 0, 0xa2a22a, 0,
  0xbbbb35, 0, 0xd2d240, 0, 0xe8e84a, 0, 0xfcfc54, 0,
  0x7c2c00, 0, 0x904811, 0, 0xa26221, 0, 0xb47a30, 0,
  0xc3903d, 0, 0xd2a44a, 0, 0xdfb755, 0, 0xecc860, 0,
  0x901c00, 0, 0xa33915, 0, 0xb55328, 0, 0xc66c3a, 0,
  0xd5824a, 0, 0xe39759, 0, 0xf0aa67, 0, 0xfcbc74, 0,
  0x940000, 0, 0xa71a1a, 0, 0xb83232, 0, 0xc84848, 0,
  0xd65c5c, 0, 0xe46f6f, 0, 0xf08080, 0, 0xfc9090, 0,
  0x840064, 0, 0x97197a, 0, 0xa8308f, 0, 0xb846a2, 0,
  0xc659b3, 0, 0xd46cc3, 0, 0xe07cd2, 0, 0xec8ce0, 0,
  0x500084, 0, 0x68199a, 0, 0x7d30ad, 0, 0x9246c0, 0,
  0xa459d0, 0, 0xb56ce0, 0, 0xc57cee, 0, 0xd48cfc, 0,
  0x140090, 0, 0x331aa3, 0, 0x4e32b5, 0, 0x6848c6, 0,
  0x7f5cd5, 0, 0x956fe3, 0, 0xa980f0, 0, 0xbc90fc, 0,
  0x000094, 0, 0x181aa7, 0, 0x2d32b8, 0, 0x4248c8, 0,
  0x545cd6, 0, 0x656fe4, 0, 0x7580f0, 0, 0x8490fc, 0,
  0x001c88, 0, 0x183b9d, 0, 0x2d57b0, 0, 0x4272c2, 0,
  0x548ad2, 0, 0x65a0e1, 0, 0x75b5ef, 0, 0x84c8fc, 0,
  0x003064, 0, 0x185080, 0, 0x2d6d98, 0, 0x4288b0, 0,
  0x54a0c5, 0, 0x65b7d9, 0, 0x75cceb, 0, 0x84e0fc, 0,
  0x004030, 0, 0x18624e, 0, 0x2d8169, 0, 0x429e82, 0,
  0x54b899, 0, 0x65d1ae, 0, 0x75e7c2, 0, 0x84fcd4, 0,
  0x004400, 0, 0x1a661a, 0, 0x328432, 0, 0x48a048, 0,
  0x5cba5c, 0, 0x6fd26f, 0, 0x80e880, 0, 0x90fc90, 0,
  0x143c00, 0, 0x355f18, 0, 0x527e2d, 0, 0x6e9c42, 0,
  0x87b754, 0, 0x9ed065, 0, 0xb4e775, 0, 0xc8fc84, 0,
  0x303800, 0, 0x505916, 0, 0x6d762b, 0, 0x88923e, 0,
  0xa0ab4f, 0, 0xb7c25f, 0, 0xccd86e, 0, 0xe0ec7c, 0,
  0x482c00, 0, 0x694d14, 0, 0x866a26, 0, 0xa28638, 0,
  0xbb9f47, 0, 0xd2b656, 0, 0xe8cc63, 0, 0xfce070, 0
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const PaletteArray PaletteHandler::ourPALPalette = {
#if 0
  0x000000, 0, 0x121212, 0, 0x242424, 0, 0x484848, 0, // 180 0
  0x6c6c6c, 0, 0x909090, 0, 0xb4b4b4, 0, 0xd8d8d8, 0, // was 0x111111..0xcccccc
  0x000000, 0, 0x121212, 0, 0x242424, 0, 0x484848, 0, // 198 1
  0x6c6c6c, 0, 0x909090, 0, 0xb4b4b4, 0, 0xd8d8d8, 0,
  0x1d0f00, 0, 0x3f2700, 0, 0x614900, 0, 0x836b01, 0, // 1b0 2
  0xa58d23, 0, 0xc7af45, 0, 0xe9d167, 0, 0xffe789, 0, // was ..0xfff389
  0x002400, 0, 0x004600, 0, 0x216800, 0, 0x438a07, 0, // 1c8 3
  0x65ac29, 0, 0x87ce4b, 0, 0xa9f06d, 0, 0xc8ff91, 0,
  0x340000, 0, 0x561400, 0, 0x783602, 0, 0x9a5824, 0, // 1e0 4
  0xbc7a46, 0, 0xde9c68, 0, 0xffbe8a, 0, 0xffd0ad, 0, // was ..0xffe0ac
  0x002700, 0, 0x004900, 0, 0x0c6b0c, 0, 0x2e8d2e, 0, // 1f8 5
  0x50af50, 0, 0x72d172, 0, 0x94f394, 0, 0xb6ffb6, 0,
  0x3d0008, 0, 0x610511, 0, 0x832733, 0, 0xa54955, 0, // 210 6
  0xc76b77, 0, 0xe98d99, 0, 0xffafbb, 0, 0xffd1d7, 0, // was 0x3f0000..0xffd1dd
  0x001e12, 0, 0x004228, 0, 0x046540, 0, 0x268762, 0, // 228 7
  0x48a984, 0, 0x6acba6, 0, 0x8cedc8, 0, 0xafffe0, 0, // was 0x002100, 0x00431e..0xaeffff
  0x300025, 0, 0x5f0047, 0, 0x811e69, 0, 0xa3408b, 0, // 240 8
  0xc562ad, 0, 0xe784cf, 0, 0xffa8ea, 0, 0xffc9f2, 0, // was ..0xffa6f1, 0xffc8ff
  0x001431, 0, 0x003653, 0, 0x0a5875, 0, 0x2c7a97, 0, // 258 9
  0x4e9cb9, 0, 0x70bedb, 0, 0x92e0fd, 0, 0xb4ffff, 0,
  0x2c0052, 0, 0x4e0074, 0, 0x701d96, 0, 0x923fb8, 0, // 270 a
  0xb461da, 0, 0xd683fc, 0, 0xe2a5ff, 0, 0xeec9ff, 0, // was ..0xf8a5ff, 0xffc7ff
  0x001759, 0, 0x00247c, 0, 0x1d469e, 0, 0x3f68c0, 0, // 288 b
  0x618ae2, 0, 0x83acff, 0, 0xa5ceff, 0, 0xc7f0ff, 0,
  0x12006d, 0, 0x34038f, 0, 0x5625b1, 0, 0x7847d3, 0, // 2a0 c
  0x9a69f5, 0, 0xb48cff, 0, 0xc9adff, 0, 0xe1d1ff, 0, // was ..0xbc8bff, 0xdeadff, 0xffcfff,
  0x000070, 0, 0x161292, 0, 0x3834b4, 0, 0x5a56d6, 0, // 2b8 d
  0x7c78f8, 0, 0x9e9aff, 0, 0xc0bcff, 0, 0xe2deff, 0,
  0x000000, 0, 0x121212, 0, 0x242424, 0, 0x484848, 0, // 2d0 e
  0x6c6c6c, 0, 0x909090, 0, 0xb4b4b4, 0, 0xd8d8d8, 0,
  0x000000, 0, 0x121212, 0, 0x242424, 0, 0x484848, 0, // 2e8 f
  0x6c6c6c, 0, 0x909090, 0, 0xb4b4b4, 0, 0xd8d8d8, 0,
#else
  0x0b0b0b, 0, 0x333333, 0, 0x595959, 0, 0x7b7b7b, 0, // 0
  0x8b8b8b, 0, 0xaaaaaa, 0, 0xc7c7c7, 0, 0xe3e3e3, 0,
  0x000000, 0, 0x272727, 0, 0x404040, 0, 0x696969, 0, // 1
  0x8b8b8b, 0, 0xaaaaaa, 0, 0xc7c7c7, 0, 0xe3e3e3, 0,
  0x3b2400, 0, 0x664700, 0, 0x8b7000, 0, 0xac9200, 0, // 2
  0xc5ae36, 0, 0xdec85e, 0, 0xf7e27f, 0, 0xfff19e, 0,
  0x004500, 0, 0x006f00, 0, 0x3b9200, 0, 0x65b009, 0, // 3
  0x85ca3d, 0, 0xa3e364, 0, 0xbffc84, 0, 0xd5ffa5, 0,
  0x590000, 0, 0x802700, 0, 0xa15700, 0, 0xbc7937, 0, // 4
  0xd6985f, 0, 0xeeb381, 0, 0xffce9e, 0, 0xffdcbd, 0,
  0x004900, 0, 0x007200, 0, 0x169216, 0, 0x45af45, 0, // 5
  0x6bc96b, 0, 0x8be38b, 0, 0xa9fba9, 0, 0xc5ffc5, 0,
  0x640012, 0, 0x890821, 0, 0xa73d4d, 0, 0xc26472, 0, // 6
  0xdc8491, 0, 0xf4a3ae, 0, 0xffbeca, 0, 0xffdae0, 0,
  0x003d29, 0, 0x006a48, 0, 0x048e63, 0, 0x3caa84, 0, // 7
  0x62c5a2, 0, 0x83dfbe, 0, 0xa1f8d9, 0, 0xbeffe9, 0,
  0x550046, 0, 0x88006e, 0, 0xa5318d, 0, 0xc159aa, 0, // 8
  0xda7cc5, 0, 0xf39adf, 0, 0xffb9f3, 0, 0xffd4f6, 0,
  0x003651, 0, 0x005a7d, 0, 0x117e9c, 0, 0x429cb8, 0, // 9
  0x68b7d2, 0, 0x88d2eb, 0, 0xa6ebff, 0, 0xc3ffff, 0,
  0x4c007c, 0, 0x75009d, 0, 0x932eb8, 0, 0xaf57d2, 0, // A
  0xca7aeb, 0, 0xe499ff, 0, 0xecb7ff, 0, 0xf3d4ff, 0,
  0x002d83, 0, 0x003ea4, 0, 0x2d65bf, 0, 0x5685da, 0, // B
  0x79a2f2, 0, 0x99bfff, 0, 0xb7dbff, 0, 0xd3f5ff, 0,
  0x220096, 0, 0x5200b6, 0, 0x7538cf, 0, 0x945fe8, 0, // C
  0xb181ff, 0, 0xc5a0ff, 0, 0xd6bdff, 0, 0xe8daff, 0,
  0x00009a, 0, 0x241db6, 0, 0x504ad0, 0, 0x746fe9, 0, // D
  0x928eff, 0, 0xb1adff, 0, 0xcecaff, 0, 0xe9e5ff, 0,
  0x0b0b0b, 0, 0x333333, 0, 0x595959, 0, 0x7b7b7b, 0, // E
  0x999999, 0, 0xb6b6b6, 0, 0xcfcfcf, 0, 0xe6e6e6, 0,
  0x0b0b0b, 0, 0x333333, 0, 0x595959, 0, 0x7b7b7b, 0, // F
  0x999999, 0, 0xb6b6b6, 0, 0xcfcfcf, 0, 0xe6e6e6, 0,
#endif
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const PaletteArray PaletteHandler::ourSECAMPalette = {
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff50ff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const PaletteArray PaletteHandler::ourNTSCPaletteZ26 = {
  0x000000, 0, 0x505050, 0, 0x646464, 0, 0x787878, 0,
  0x8c8c8c, 0, 0xa0a0a0, 0, 0xb4b4b4, 0, 0xc8c8c8, 0,
  0x445400, 0, 0x586800, 0, 0x6c7c00, 0, 0x809000, 0,
  0x94a414, 0, 0xa8b828, 0, 0xbccc3c, 0, 0xd0e050, 0,
  0x673900, 0, 0x7b4d00, 0, 0x8f6100, 0, 0xa37513, 0,
  0xb78927, 0, 0xcb9d3b, 0, 0xdfb14f, 0, 0xf3c563, 0,
  0x7b2504, 0, 0x8f3918, 0, 0xa34d2c, 0, 0xb76140, 0,
  0xcb7554, 0, 0xdf8968, 0, 0xf39d7c, 0, 0xffb190, 0,
  0x7d122c, 0, 0x912640, 0, 0xa53a54, 0, 0xb94e68, 0,
  0xcd627c, 0, 0xe17690, 0, 0xf58aa4, 0, 0xff9eb8, 0,
  0x730871, 0, 0x871c85, 0, 0x9b3099, 0, 0xaf44ad, 0,
  0xc358c1, 0, 0xd76cd5, 0, 0xeb80e9, 0, 0xff94fd, 0,
  0x5d0b92, 0, 0x711fa6, 0, 0x8533ba, 0, 0x9947ce, 0,
  0xad5be2, 0, 0xc16ff6, 0, 0xd583ff, 0, 0xe997ff, 0,
  0x401599, 0, 0x5429ad, 0, 0x683dc1, 0, 0x7c51d5, 0,
  0x9065e9, 0, 0xa479fd, 0, 0xb88dff, 0, 0xcca1ff, 0,
  0x252593, 0, 0x3939a7, 0, 0x4d4dbb, 0, 0x6161cf, 0,
  0x7575e3, 0, 0x8989f7, 0, 0x9d9dff, 0, 0xb1b1ff, 0,
  0x0f3480, 0, 0x234894, 0, 0x375ca8, 0, 0x4b70bc, 0,
  0x5f84d0, 0, 0x7398e4, 0, 0x87acf8, 0, 0x9bc0ff, 0,
  0x04425a, 0, 0x18566e, 0, 0x2c6a82, 0, 0x407e96, 0,
  0x5492aa, 0, 0x68a6be, 0, 0x7cbad2, 0, 0x90cee6, 0,
  0x044f30, 0, 0x186344, 0, 0x2c7758, 0, 0x408b6c, 0,
  0x549f80, 0, 0x68b394, 0, 0x7cc7a8, 0, 0x90dbbc, 0,
  0x0f550a, 0, 0x23691e, 0, 0x377d32, 0, 0x4b9146, 0,
  0x5fa55a, 0, 0x73b96e, 0, 0x87cd82, 0, 0x9be196, 0,
  0x1f5100, 0, 0x336505, 0, 0x477919, 0, 0x5b8d2d, 0,
  0x6fa141, 0, 0x83b555, 0, 0x97c969, 0, 0xabdd7d, 0,
  0x344600, 0, 0x485a00, 0, 0x5c6e14, 0, 0x708228, 0,
  0x84963c, 0, 0x98aa50, 0, 0xacbe64, 0, 0xc0d278, 0,
  0x463e00, 0, 0x5a5205, 0, 0x6e6619, 0, 0x827a2d, 0,
  0x968e41, 0, 0xaaa255, 0, 0xbeb669, 0, 0xd2ca7d, 0
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const PaletteArray PaletteHandler::ourPALPaletteZ26 = {
  0x000000, 0, 0x4c4c4c, 0, 0x606060, 0, 0x747474, 0,
  0x888888, 0, 0x9c9c9c, 0, 0xb0b0b0, 0, 0xc4c4c4, 0,
  0x000000, 0, 0x4c4c4c, 0, 0x606060, 0, 0x747474, 0,
  0x888888, 0, 0x9c9c9c, 0, 0xb0b0b0, 0, 0xc4c4c4, 0,
  0x533a00, 0, 0x674e00, 0, 0x7b6203, 0, 0x8f7617, 0,
  0xa38a2b, 0, 0xb79e3f, 0, 0xcbb253, 0, 0xdfc667, 0,
  0x1b5800, 0, 0x2f6c00, 0, 0x438001, 0, 0x579415, 0,
  0x6ba829, 0, 0x7fbc3d, 0, 0x93d051, 0, 0xa7e465, 0,
  0x6a2900, 0, 0x7e3d12, 0, 0x925126, 0, 0xa6653a, 0,
  0xba794e, 0, 0xce8d62, 0, 0xe2a176, 0, 0xf6b58a, 0,
  0x075b00, 0, 0x1b6f11, 0, 0x2f8325, 0, 0x439739, 0,
  0x57ab4d, 0, 0x6bbf61, 0, 0x7fd375, 0, 0x93e789, 0,
  0x741b2f, 0, 0x882f43, 0, 0x9c4357, 0, 0xb0576b, 0,
  0xc46b7f, 0, 0xd87f93, 0, 0xec93a7, 0, 0xffa7bb, 0,
  0x00572e, 0, 0x106b42, 0, 0x247f56, 0, 0x38936a, 0,
  0x4ca77e, 0, 0x60bb92, 0, 0x74cfa6, 0, 0x88e3ba, 0,
  0x6d165f, 0, 0x812a73, 0, 0x953e87, 0, 0xa9529b, 0,
  0xbd66af, 0, 0xd17ac3, 0, 0xe58ed7, 0, 0xf9a2eb, 0,
  0x014c5e, 0, 0x156072, 0, 0x297486, 0, 0x3d889a, 0,
  0x519cae, 0, 0x65b0c2, 0, 0x79c4d6, 0, 0x8dd8ea, 0,
  0x5f1588, 0, 0x73299c, 0, 0x873db0, 0, 0x9b51c4, 0,
  0xaf65d8, 0, 0xc379ec, 0, 0xd78dff, 0, 0xeba1ff, 0,
  0x123b87, 0, 0x264f9b, 0, 0x3a63af, 0, 0x4e77c3, 0,
  0x628bd7, 0, 0x769feb, 0, 0x8ab3ff, 0, 0x9ec7ff, 0,
  0x451e9d, 0, 0x5932b1, 0, 0x6d46c5, 0, 0x815ad9, 0,
  0x956eed, 0, 0xa982ff, 0, 0xbd96ff, 0, 0xd1aaff, 0,
  0x2a2b9e, 0, 0x3e3fb2, 0, 0x5253c6, 0, 0x6667da, 0,
  0x7a7bee, 0, 0x8e8fff, 0, 0xa2a3ff, 0, 0xb6b7ff, 0,
  0x000000, 0, 0x4c4c4c, 0, 0x606060, 0, 0x747474, 0,
  0x888888, 0, 0x9c9c9c, 0, 0xb0b0b0, 0, 0xc4c4c4, 0,
  0x000000, 0, 0x4c4c4c, 0, 0x606060, 0, 0x747474, 0,
  0x888888, 0, 0x9c9c9c, 0, 0xb0b0b0, 0, 0xc4c4c4, 0
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const PaletteArray PaletteHandler::ourSECAMPaletteZ26 = {
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0,
  0x000000, 0, 0x2121ff, 0, 0xf03c79, 0, 0xff3cff, 0,
  0x7fff00, 0, 0x7fffff, 0, 0xffff3f, 0, 0xffffff, 0
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteArray PaletteHandler::ourUserNTSCPalette  = { 0 }; // filled from external file

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteArray PaletteHandler::ourUserPALPalette   = { 0 }; // filled from external file

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteArray PaletteHandler::ourUserSECAMPalette = { 0 }; // filled from external file

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteArray PaletteHandler::ourCustomNTSCPalette = { 0 }; // filled by function

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaletteArray PaletteHandler::ourCustomPALPalette  = { 0 }; // filled by function
