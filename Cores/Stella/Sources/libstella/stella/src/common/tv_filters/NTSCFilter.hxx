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

#ifndef NTSC_FILTER_HXX
#define NTSC_FILTER_HXX

class TIASurface;
class Settings;

#include "bspf.hxx"
#include "AtariNTSC.hxx"
#include "FrameBufferConstants.hxx"

/**
  This class is based on the Blargg NTSC filter code from Atari800,
  and is derived from 'filter_ntsc.(h|c)'.  Original code based on
  implementation from http://www.slack.net/~ant.

  The class is basically a thin wrapper around the AtariNTSC class.
*/
class NTSCFilter
{
  public:
    NTSCFilter() = default;

  public:
    // Set one of the available preset adjustments (Composite, S-Video, RGB, etc)
    enum class Preset {
      OFF,
      RGB,
      SVIDEO,
      COMPOSITE,
      BAD,
      CUSTOM
    };
    enum class Adjustables {
      SHARPNESS,
      RESOLUTION,
      ARTIFACTS,
      FRINGING,
      BLEEDING,
      NUM_ADJUSTABLES
    };

    /* Normally used in conjunction with custom mode, contains all
       aspects currently adjustable in NTSC TV emulation. */
    struct Adjustable {
      uInt32 sharpness{0}, resolution{0}, artifacts{0}, fringing{0}, bleed{0};
    };

  public:
    /* Informs the NTSC filter about the current TIA palette.  The filter
       uses this as a baseline for calculating its own internal palette
       in YIQ format.
    */
    void setPalette(const PaletteArray& palette) {
      myNTSC.setPalette(palette);
    }

    // The following are meant to be used strictly for toggling from the GUI
    string setPreset(Preset preset);

    // Get current preset info encoded as a string
    string getPreset() const;

    // Get adjustables for the given preset
    // Values will be scaled to 0 - 100 range, independent of how
    // they're actually stored internally
    static void getAdjustables(Adjustable& adjustable, Preset preset);

    // Set custom adjustables to given values
    // Values will be scaled to 0 - 100 range, independent of how
    // they're actually stored internally
    static void setCustomAdjustables(const Adjustable& adjustable);

    // The following methods cycle through each custom adjustable
    // They are used in conjunction with the increase/decrease
    // methods, which change the currently selected adjustable
    // Changes are made this way since otherwise 20 key-combinations
    // would be needed to dynamically change each setting, and now
    // only 4 combinations are necessary
    void selectAdjustable(int direction,
                          string& text, string& valueText, Int32& value);
    void changeAdjustable(int adjustable, int direction,
                          string& text, string& valueText, Int32& newValue);
    void changeCurrentAdjustable(int direction,
                                 string& text, string& valueText, Int32& newValue);

    // Load and save NTSC-related settings
    static void loadConfig(const Settings& settings);
    static void saveConfig(Settings& settings);

    // Perform Blargg filtering on input buffer, place results in
    // output buffer
    inline void render(const uInt8* src_buf, uInt32 src_width, uInt32 src_height,
                       uInt32* dest_buf, uInt32 dest_pitch)
    {
      myNTSC.render(src_buf, src_width, src_height, dest_buf, dest_pitch);
    }
    inline void render(const uInt8* src_buf, uInt32 src_width, uInt32 src_height,
                       uInt32* dest_buf, uInt32 dest_pitch, uInt32* prev_buf)
    {
      myNTSC.render(src_buf, src_width, src_height, dest_buf, dest_pitch, prev_buf);
    }

    // Enable threading for the NTSC rendering
    inline void enableThreading(bool enable)
    {
      myNTSC.enableThreading(enable);
    }

  private:
    // Convert from atari_ntsc_setup_t values to equivalent adjustables
    static void convertToAdjustable(Adjustable& adjustable,
                                    const AtariNTSC::Setup& setup);

  private:
    // The NTSC object
    AtariNTSC myNTSC;

    // Contains controls used to adjust the palette in the NTSC filter
    // This is the main setup object used by the underlying ntsc code
    AtariNTSC::Setup mySetup{AtariNTSC::TV_Composite};

    // This setup is used only in custom mode (after it is modified,
    // it is copied to mySetup)
    static AtariNTSC::Setup myCustomSetup;

    // Current preset in use
    Preset myPreset{Preset::OFF};

    struct AdjustableTag {
      string_view type;
      float* value{nullptr};
    };
    uInt32 myCurrentAdjustable{0};

    static constexpr std::array<AdjustableTag, 5> ourCustomAdjustables = {{
      { "sharpness", &myCustomSetup.sharpness },
      { "resolution", &myCustomSetup.resolution },
      { "artifacts", &myCustomSetup.artifacts },
      { "fringing", &myCustomSetup.fringing },
      { "bleeding", &myCustomSetup.bleed }
    }};

  private:
    // Following constructors and assignment operators not supported
    NTSCFilter(const NTSCFilter&) = delete;
    NTSCFilter(NTSCFilter&&) = delete;
    NTSCFilter& operator=(const NTSCFilter&) = delete;
    NTSCFilter& operator=(NTSCFilter&&) = delete;
};

#endif
