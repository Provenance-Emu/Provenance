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

#ifndef PALETTE_HANDLER_HXX
#define PALETTE_HANDLER_HXX

#include "bspf.hxx"
#include "OSystem.hxx"
#include "ConsoleTiming.hxx"
#include "EventHandlerConstants.hxx"

class PaletteHandler
{
  public:
    // Setting names of palette types
    static constexpr string_view SETTING_STANDARD = "standard";
    static constexpr string_view SETTING_Z26 = "z26";
    static constexpr string_view SETTING_USER = "user";
    static constexpr string_view SETTING_CUSTOM = "custom";

    // Phase shift default and limits
    static constexpr float DEF_NTSC_SHIFT = 26.2F;
    static constexpr float DEF_PAL_SHIFT = 31.3F; // ~= 360 / 11.5
    static constexpr float MAX_PHASE_SHIFT = 4.5F;
    static constexpr float DEF_RGB_SHIFT = 0.0F;
    static constexpr float MAX_RGB_SHIFT = 22.5F;

    enum Adjustables : uInt32 {
      PHASE_SHIFT,
      RED_SCALE,
      GREEN_SCALE,
      BLUE_SCALE,
      RED_SHIFT,
      GREEN_SHIFT,
      BLUE_SHIFT,
      HUE,
      SATURATION,
      CONTRAST,
      BRIGHTNESS,
      GAMMA,
      CUSTOM_START = PHASE_SHIFT,
      CUSTOM_END = BLUE_SHIFT,
    };

    // Externally used adjustment parameters
    struct Adjustable {
      float phaseNtsc{0.F}, phasePal{0.F},
        redScale{0.F}, greenScale{0.F}, blueScale{0.F},
        redShift{0.F}, greenShift{0.F}, blueShift{0.F};
      uInt32 hue{0}, saturation{0}, contrast{0}, brightness{0}, gamma{0};
    };

  public:
    explicit PaletteHandler(OSystem& system);

    /**
      Cycle through available palettes.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void cyclePalette(int direction = +1);

    /*
      Cycle through each palette adjustable.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void cycleAdjustable(int direction = +1);

    /*
      Increase or decrease given palette adjustable.

      @param adjustable  The adjustable to change
      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeAdjustable(int adjustable, int direction);

    /*
      Increase or decrease current palette adjustable.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeCurrentAdjustable(int direction = +1);

    // Load adjustables from settings
    void loadConfig(const Settings& settings);

    // Save adjustables to settings
    void saveConfig(Settings& settings) const;

    // Set adjustables
    void setAdjustables(const Adjustable& adjustable);

    // Retrieve current adjustables
    void getAdjustables(Adjustable& adjustable) const;

    /**
      Sets the palette according to the given palette name.

      @param name  The palette to switch to
    */
    void setPalette(string_view name);

    /**
      Sets the palette from current settings.
    */
    void setPalette();


  private:
    static constexpr char DEGREE = 0x1c;

    enum PaletteType {
      Standard,
      Z26,
      User,
      Custom,
      NumTypes,
      MinType = Standard,
      MaxType = Custom
    };

    struct vector2d {
      float x{0.F};
      float y{0.F};

      explicit vector2d(float _x = 0.F, float _y = 0.F)
        : x{_x}, y{_y} { }
    };

    /**
      Convert RGB adjustables from/to 100% scale
    */
    static constexpr float scaleRGBFrom100(float x) { return x / 50.F; }
    static constexpr uInt32 scaleRGBTo100(float x) { return static_cast<uInt32>(50.0001F * (x - 0.F)); }

    /**
      Convert angles
    */
    static constexpr float scaleFromAngles(float x) { return x / 10.F; }
    static constexpr Int32 scaleToAngles(float x) { return static_cast<uInt32>(10.F * x); }

    /**
      Convert adjustables from/to 100% scale
    */
    static constexpr float scaleFrom100(float x) { return (x / 50.F) - 1.F; }
    static constexpr uInt32 scaleTo100(float x)  { return static_cast<uInt32>(50.0001F * (x + 1.F)); }

    /**
      Check for 'Custom' palette only adjustables
    */
    bool isCustomAdjustable() const;

    bool isPhaseShift() const;

    bool isRGBScale() const;

    bool isRGBShift() const;

    /**
      Convert palette settings name to enumeration.

      @param name  The given palette's settings name

      @return  The palette type
    */
    PaletteType toPaletteType(string_view name) const;

    /**
      Convert enumeration to palette settings name.

      @param type  The given palette type

      @return  The palette's settings name
    */
    static string_view toPaletteName(PaletteType type);

    /**
      Display current adjustable with gauge bar message
    */
    void showAdjustableMessage();

    /**
      Change the "phase shift" variable.
      Note that there are two of these (NTSC and PAL).  The currently
      active mode will determine which one is used.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeColorPhaseShift(int direction = +1);

    /**
      Generates a custom palette, based on user defined phase shifts.

      @param timing  Use NTSC or PAL phase shift and generate according palette
    */
    void generateCustomPalette(ConsoleTiming timing) const;

    /**
      Create new palette by applying palette adjustments on given palette.

      @param palette  The palette which should be adjusted

      @return  An adjusted palette
    */
    PaletteArray adjustedPalette(const PaletteArray& palette) const;

    /**
      Adjust hue and saturation for given RGB values.

      @param R  The red value to adjust
      @param G  The green value to adjust
      @param B  The blue value to adjust
      @param H  The hue adjustment value
      @param S  The saturation
    */
    static void adjustHueSaturation(int& R, int& G, int& B, float H, float S);

    /**
      Rotate a 2D vector.
    */
    static vector2d rotate(const vector2d& vec, float angle);

    /**
      Scale a 2D vector.
    */
    static vector2d scale(const vector2d& vec, float factor);

    /**
      Get the dot product of two 2D vectors.
    */
    static float dotProduct(const vector2d& vec1, const vector2d& vec2);

    /**
      Loads a user-defined palette file (from OSystem::paletteFile), filling the
      appropriate user-defined palette arrays.
    */
    void loadUserPalette();

  private:
    static constexpr int NUM_ADJUSTABLES = 12;

    OSystem& myOSystem;

    // The currently selected adjustable
    uInt32 myCurrentAdjustable{0};

    struct AdjustableTag {
      string_view name;
      float* value{nullptr};
    };
    const std::array<AdjustableTag, NUM_ADJUSTABLES> myAdjustables =
    { {
      { "phase shift", nullptr },
      { "red scale", &myRedScale },
      { "green scale", &myGreenScale },
      { "blue scale", &myBlueScale },
      { "red shift", &myRedShift },
      { "green shift", &myGreenShift },
      { "blue shift", &myBlueShift },
      { "hue", &myHue },
      { "saturation", &mySaturation },
      { "contrast", &myContrast },
      { "brightness", &myBrightness },
      { "gamma", &myGamma },
    } };

    // NTSC and PAL color phase shifts
    float myPhaseNTSC{DEF_NTSC_SHIFT};
    float myPhasePAL{DEF_PAL_SHIFT};
    // Color intensities
    float myRedScale{1.0F};
    float myGreenScale{1.0F};
    float myBlueScale{1.0F};
    // Color shifts
    float myRedShift{0.0F};
    float myGreenShift{0.0F};
    float myBlueShift{0.0F};
    // range -1.0 to +1.0 (as in AtariNTSC)
    // Basic parameters
    float myHue{0.0F};        // -1 = -180 degrees     +1 = +180 degrees
    float mySaturation{0.0F}; // -1 = grayscale (0.0)  +1 = oversaturated colors (2.0)
    float myContrast{0.0F};   // -1 = dark (0.5)       +1 = light (1.5)
    float myBrightness{0.0F}; // -1 = dark (0.5)       +1 = light (1.5)
    // Advanced parameters
    float myGamma{0.0F};      // -1 = dark (1.5)       +1 = light (0.5)

    // Indicates whether an external palette was found and
    // successfully loaded
    bool myUserPaletteDefined{false};

    // Table of RGB values for NTSC, PAL and SECAM
    static const PaletteArray ourNTSCPalette;
    static const PaletteArray ourPALPalette;
    static const PaletteArray ourSECAMPalette;

    // Table of RGB values for NTSC, PAL and SECAM - Z26 version
    static const PaletteArray ourNTSCPaletteZ26;
    static const PaletteArray ourPALPaletteZ26;
    static const PaletteArray ourSECAMPaletteZ26;

    // Table of RGB values for NTSC, PAL and SECAM - user-defined
    static PaletteArray ourUserNTSCPalette;
    static PaletteArray ourUserPALPalette;
    static PaletteArray ourUserSECAMPalette;

    // Table of RGB values for NTSC, PAL - custom-defined and generated
    static PaletteArray ourCustomNTSCPalette;
    static PaletteArray ourCustomPALPalette;

  private:
    PaletteHandler() = delete;
    PaletteHandler(const PaletteHandler&) = delete;
    PaletteHandler(PaletteHandler&&) = delete;
    PaletteHandler& operator=(const PaletteHandler&) = delete;
    PaletteHandler& operator=(const PaletteHandler&&) = delete;
};

#endif // PALETTE_HANDLER_HXX
